import os
import json
import subprocess
from jinja2 import Environment, FileSystemLoader

# --- Configuration ---
TEMPLATE_DIR = '/app/config-generator/templates'
PROXY_OUTPUT_DIR = '/config/nginx/proxy-confs'
DEFAULT_CONF_OUTPUT = '/config/nginx/site-confs/default.conf'
HTPASSWD_FILE = '/config/nginx/.htpasswd'
# ---------------------

def process_service_config(service_name, service_config_json, global_auth_provider, auth_exclude_list):
    """Processes a single service configuration, including auth logic."""
    service_config = json.loads(service_config_json)
    
    # The default service doesn't have a subdomain name in the traditional sense
    if service_name.lower() == 'default':
        # We still need a target container name, let the user define it or raise an error
        if 'name' not in service_config:
             raise ValueError("PROXY_CONFIG_DEFAULT must contain a 'name' key specifying the target container name.")
    else:
        service_config['name'] = service_name

    # --- Authentication Logic ---
    auth_provider = 'none' # Default
    # 1. Per-service override
    if 'auth' in service_config:
        auth_provider = service_config['auth']
        print(f"    - Found per-service auth override: '{auth_provider}'")
    # 2. Global provider check
    elif global_auth_provider and service_name not in auth_exclude_list:
        auth_provider = global_auth_provider
        print(f"    - Applying global auth provider: '{auth_provider}'")
    # 3. Otherwise, no auth
    else:
        if service_name in auth_exclude_list:
                print(f"    - Service is in global exclude list. No auth.")
        else:
                print(f"    - No auth provider specified.")

    service_config['auth_provider'] = auth_provider
    return service_config

def generate_configs():
    """
    Generates Nginx config files from PROXY_CONFIG environment variables and a Jinja2 template.
    """
    print("--- Starting Nginx Config Generation from Environment Variables ---")

    # Ensure output directories exist
    os.makedirs(PROXY_OUTPUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(DEFAULT_CONF_OUTPUT), exist_ok=True)
    print(f"Output directories are ready.")

    # Get global auth settings from environment variables
    global_auth_provider = os.environ.get('PROXY_AUTH_PROVIDER')
    auth_exclude_list = os.environ.get('PROXY_AUTH_EXCLUDE', '').split(',')
    auth_exclude_list = [name.strip() for name in auth_exclude_list if name.strip()]

    # Get basic auth credentials
    basic_auth_user = os.environ.get('PROXY_AUTH_BASIC_USER')
    basic_auth_pass = os.environ.get('PROXY_AUTH_BASIC_PASS')
    basic_auth_configured = False

    print(f"Global Auth Provider: {global_auth_provider}")
    print(f"Auth Exclude List: {auth_exclude_list}")

    # Collect and process service configurations
    subdomain_services = []
    default_service = None

    for key, value in os.environ.items():
        if key.startswith('PROXY_CONFIG_'):
            service_name = key.replace('PROXY_CONFIG_', '').lower()
            print(f"  Processing service: {service_name}")
            print(value)
            try:
                service_config = process_service_config(service_name, value, global_auth_provider, auth_exclude_list)

                # Handle Basic Auth File Creation
                if service_config['auth_provider'] == 'basic' and not basic_auth_configured:
                    if basic_auth_user and basic_auth_pass:
                        print(f"    - Configuring Basic Auth with user '{basic_auth_user}'.")
                        try:
                            os.makedirs(os.path.dirname(HTPASSWD_FILE), exist_ok=True)
                            command = ['htpasswd', '-bc', HTPASSWD_FILE, basic_auth_user, basic_auth_pass]
                            subprocess.run(command, check=True, capture_output=True, text=True)
                            print(f"    - Successfully created '{HTPASSWD_FILE}'.")
                            basic_auth_configured = True
                        except subprocess.CalledProcessError as e:
                            print(f"    [!!] ERROR: 'htpasswd' command failed: {e.stderr}. Basic auth will not be enabled.")
                            service_config['auth_provider'] = 'none'
                        except FileNotFoundError:
                            print(f"    [!!] ERROR: 'htpasswd' command not found. Basic auth will not be enabled.")
                            service_config['auth_provider'] = 'none'
                    else:
                        print(f"    [!!] WARNING: 'auth: basic' is set, but PROXY_AUTH_BASIC_USER or PROXY_AUTH_BASIC_PASS is missing. Skipping auth.")
                        service_config['auth_provider'] = 'none'
                
                if service_name == 'default':
                    default_service = service_config
                else:
                    subdomain_services.append(service_config)

            except (json.JSONDecodeError, ValueError) as e:
                print(f"  [!!] ERROR: Could not parse or validate config for {service_name}: {e}. Skipping.")
            except Exception as e:
                print(f"  [!!] ERROR: An unexpected error occurred processing {service_name}: {e}. Skipping.")

    # Set up Jinja2 environment
    try:
        env = Environment(loader=FileSystemLoader(TEMPLATE_DIR), trim_blocks=True, lstrip_blocks=True)
        proxy_template = env.get_template('proxy.conf.j2')
        default_template = env.get_template('default.conf.j2')
        print("\nJinja2 templates loaded successfully.")
    except Exception as e:
        print(f"ERROR: Failed to load Jinja2 templates from '{TEMPLATE_DIR}': {e}. Exiting.")
        return

    # Generate default site config if specified
    if default_service:
        print("\n--- Generating Default Site Config ---")
        try:
            rendered_content = default_template.render(item=default_service)
            with open(DEFAULT_CONF_OUTPUT, 'w') as f:
                f.write(rendered_content)
            print(f"  [OK] Generated {os.path.basename(DEFAULT_CONF_OUTPUT)}")
        except Exception as e:
            print(f"  [!!] ERROR: Failed to render or write default config: {e}")
    else:
        print("\n--- PROXY_CONFIG_DEFAULT not set, default site config will not be generated. ---")


    # Generate subdomain proxy configs
    print("\n--- Generating Subdomain Proxy Configs ---")
    if not subdomain_services:
        print("No subdomain services found to configure.")
    for service in subdomain_services:
        filename = f"{service['name']}.subdomain.conf"
        output_path = os.path.join(PROXY_OUTPUT_DIR, filename)
        try:
            rendered_content = proxy_template.render(item=service)
            with open(output_path, 'w') as f:
                f.write(rendered_content)
            print(f"  [OK] Generated {filename}")
        except Exception as e:
            print(f"  [!!] ERROR: Failed to render or write config for {service['name']}: {e}")

    print("\n--- Generation Complete ---")

if __name__ == "__main__":
    generate_configs()
