#!/bin/bash
# Minecraft Startup Script v1.0.0

MCDIR="/home/your_user/minecraft"
JVMARGS="-Xmx1024M -Xms1024M -d64"
MCJAR="minecraft_server.current.jar"
MCSCREENNAME="minecraft"

### Do not modify below this line unless you know what you are doing! ###

screen -dmS $MCSCRENNAME $(which bash)
screen -S $MCSCRENNAME -X stuff "cd ${MCDIR} \n"
screen -S $MCSCRENNAME -X stuff "$(which java) ${JVMARGS} -jar ${MCJAR} nogui \n"
