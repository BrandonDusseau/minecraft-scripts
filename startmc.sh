#!/bin/bash
# Minecraft Startup Script v1.1.0

MCDIR="/home/your_user/minecraft"
JVMARGS="-Xmx1024M -Xms1024M -d64"
MCJAR="minecraft_server.current.jar"
MCSCREENNAME="minecraft"

### Do not modify below this line unless you know what you are doing! ###

screen -dmS $MCSCREENNAME $(which bash)
screen -S $MCSCREENNAME -X stuff "cd ${MCDIR} \n"
screen -S $MCSCREENNAME -X stuff "$(which bash) -c \"exec -a minecraft $(which java) ${JVMARGS} -jar ${MCJAR} nogui\" \n"
