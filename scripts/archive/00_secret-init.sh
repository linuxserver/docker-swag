#!/bin/sh

# logic cribbed from linuxserver.io: 
# https://github.com/linuxserver/docker-baseimage-ubuntu/blob/bionic/root/etc/cont-init.d/01-envfile

# iterate over environmental variables
# if variable ends in "__FILE"
for FULLVAR in $(env | grep "^.*__FILE="); do
    # trim "=..." from variable name
    VARNAME=$(echo $FULLVAR | sed "s/=.*//g")
    echo "[secret-init] Evaluating ${VARNAME}"

    # set SECRETFILE to the contents of the variable
    # Use 'eval hack' for indirect expansion in sh: https://unix.stackexchange.com/questions/111618/indirect-variable-expansion-in-posix-as-done-in-bash
    # WARNING: It's not foolproof is an arbitrary command injection vulnerability 
    eval SECRETFILE="\$${VARNAME}"

    # echo "[secret-init] Setting SECRETFILE to ${SECRETFILE} ..."  # DEBUG - rm for prod!
    
    # if SECRETFILE exists
    if [[ -f ${SECRETFILE} ]]; then
        # strip the appended "__FILE" from environmental variable name
        STRIPVAR=$(echo $VARNAME | sed "s/__FILE//g")
        # echo "[secret-init] Set STRIPVAR to ${STRIPVAR}"  # DEBUG - rm for prod!

        # set value to contents of secretfile
        eval ${STRIPVAR}=$(cat "${SECRETFILE}")
        # echo "[secret_init] Set ${STRIPVAR} to $(eval echo \$${STRIPVAR})"  # DEBUG - rm for prod!
        
        export "${STRIPVAR}"
        echo "[secret-init] Success! ${STRIPVAR} set from ${VARNAME}"
        
    else
        echo "[secret-init] ERROR: Cannot find secret in ${VARNAME}"
    fi
done
