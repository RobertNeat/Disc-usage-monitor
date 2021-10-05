#!/bin/bash

#Script monitor free space at /home/user and tries to maintain percentage given by 
#user and tries to maintain it (if free space is lower than given by user in % script
# deletes files or moves it to external usb storage)

#Script monitor /home/$USER partition usage
#Calling the script should be made with one argument in the range 5% -90% (otherwise the script returns code 7)
#NOTE - the script does not tolerate files with empty spaces in their names (they must be moved separately) - this is due to the fact that I use the awk command, which takes fields from a table

#Error codes:
#1 - value too small (less than 5%)
#2 - value too big (more than 90%)

#clear

if [ $1 -lt 5 ]
then
echo "--Error value too small!--"
exit 1
elif [ $1 -gt 90 ]
then
echo "--Error value too big!--"
exit 2
fi

######################################################################################################
#                                              FUNCTIONS                                             #
######################################################################################################

usage(){    #function checking the use of the /home/$USER partition

echo -n "Disc name: "
df ~/ | grep % | sed -n -e '2p' | cut -b -9

echo "Partition name: /home/"$USER

free=$( echo $HOME | free | sed -n -e 2p | awk '{print $4}')
echo "Amount of free space: "$free" KiBi"   
#Displays in kibibytes, if you want to change it should be changed to -m (mebibytes)
#to change the line, as if it does not work properly, change "2p" to "3p" (may be wrong line)
#the change of the displayed field depends on the "print $ 4" parameter (the number of the field separated by a tab)

size=$( echo $HOME | free | sed -n -e 2p | awk '{print $2}')
echo "Size of partition: "$size" KiBi"

busy=$( echo $HOME | free | sed -n -e 2p | awk '{print $3}')
echo "Amount of used space: "$busy" KiBi"

echo "Limit value:"$1" %"

let "size = $size / 100"
let "free = $free / $size"
echo "Now available:"$free" %"

wanted=$((free*100/size))
}

status_bar(){   #status-bar
    echo -n "["
    helper=0;

    if [ $hash -gt 59 ]
    then
    (( hash=$hash-60 ))
    fi

    a=0
    while [ $a -lt $hash ]
    do
    echo -n "#"
    (( a=$a+1 ))
    done
    
    for (( b=0;b<$(( 59-$a ));b++ ))
    do
    echo -n "-"
    done
    
    echo -n "]"
    echo
}

####################################################################################
#                          Main part                                               #
####################################################################################
hash=0 #variable to call status_bar
free=$( echo $HOME | free | sed -n -e 2p | awk '{print $4}')
size=$( echo $HOME | free | sed -n -e 2p | awk '{print $2}')
#$1 - wanted value in %

wanted=$((free*100/size)) #cheat bash with using pseudo-floating point arithmetic

clear
echo "Parameter: "$1"%"
echo "Now available: "$wanted"%"
echo "Free: "$free
echo "Size: "$size
sleep 2

while [ true ]
do

    while [ $wanted -gt $1 ] #writing down usage parameters, when value of task is lower than amount of free space in parameter otherwise cleanup is initialized
    do
        clear

        usage $1

        status_bar hash
        (( hash=$hash+1 ))
        sleep 1     #refresh amount in seconds

        #variables from function "status_bar" aren't global - don't know why
        free=$( echo $HOME | free | sed -n -e 2p | awk '{print $4}')
        size=$( echo $HOME | free | sed -n -e 2p | awk '{print $2}')
        wanted=$((free*100/size))

    done
    
echo "Limit exceeded!!"
read -p "Partition cleanup?[y/n]:" decision


while [ $decision == n ]
do
sleep 60 #wait 60 seconds before retrying question
read -p "Partition cleanup?[y/n]:" decision
done

echo "Proposed files (to delete/ move)[size in bytes] form newest:"
#Files possible to delete (size in segments)
find ~/ -not -path '*/\.*' -type f -user $USER -exec ls -s --block-size=1 -t "{}" \;     #maxdepth can be changed to broaden range of files "-maxdepth 3" (in find command)
find ~/ -not -path '*/\.*' -type f -user $USER -exec ls -s --block-size=1 -t "{}" \; > "todelete.txt"

read -p "Choose how many file do you want to modify from list (starting from first position in list):" quantity    #number of modified files
read -p "Choose action (0- delete, 1 - move to USB disc):" action   #variable action defines chosen action

if [ $action -eq 0 ]
then
    tmp=$(wc -l < todelete.txt)
    (( tmp=$tmp+1 ))

    for (( a=1;a <= $quantity;a++ ))
    do
        if [ $a -lt $tmp ]  #secure from too many read lines from todelete.txt file
        then
        location=$( sed -n "${a}"p todelete.txt | awk -F '\ ' '{print $2}' )
        rm "${location}"
        fi
    done
    rm todelete.txt

elif [ $action -eq 1 ]
then
    echo "Available USB devices:"

    lsblk -o mountpoint,hotplug | grep 1$ | awk '{print $1}'
    lsblk -o mountpoint,hotplug | grep 1$ | awk '{print $1}' > "usbdevices.txt"

    read -p "Choose device where chosen files will be moved:" usb
    tmpq=$(wc -l < usbdevices.txt)
    (( tmpq=$tmpq+1 ))
    until (( $usb < $tmpq ))
    do
    echo "Wrong device id position"
    read -p "Choose device where chosen files will be moved:" usb
    done

    chosen=$( sed -n "${usb}"p usbdevices.txt )
    #For loop to move files
    for (( a=1;a <= $quantity;a++ ))
    do
        move=$( sed -n "${a}"p todelete.txt | awk '{print $2}' )
        mv $move $chosen
    done

fi

# find ~/ -type f -user $USER  <<THIS command searches files in home directory

done