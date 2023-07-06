#!/bin/bash

# Variables allowing us to configure placement and names of the files used by this script
path=$(pwd)
file_connexion=$path/connexion
file_machine=$path/machine
file_user=$path/user

source $path/command_admin.sh
source $path/command_connect.sh


function error {
	case $1 in
		1) 
			printf "\n[-] Error : The number of parameters provided is not correct." 
                ;;
		2)
			printf "\n[-] Error : The user provided does not exist." 
                ;;
		3)
			printf "\n[-] Error : The machine provided does not exist." 
                ;;
		4)	
			printf "\n[-] Error : Wrong password." 
                ;;
		5) 
			printf "\n[-] Error : You do not have access to the requested machine or it doesn't exist." 
                ;;
		6)
            printf "\n[-] Error : The user or the machine that you selected to send your message do not exist." 
                ;;
	esac
}


function help {
    echo "Usage : rvsh [OPTION]... [USER] [MACHINE] [COMMAND] [ARGUMENTS]..."
    echo "-connect [USER] [MACHINE] [COMMAND] [ARGUMENTS]... : Connect to a machine"
    echo "-admin [COMMAND] [ARGUMENTS]... : Execute an admin command"
    echo "-help : Display this help"
}


# Function to verify the number of arguments given by the user
function argCheck { 
	if [ $1 -eq $2 ]; then
		return 0
	else
		error 1
		return 1
	fi
}


# Function to verify if the user exists
function userCheck { 
	echo "[+] Verifying if the user exists..."
	argCheck $# 1
	if [ $? -eq 0 ]; then
		user=$1
		while read line
			do
				user_name=$(echo $line | sed 's/^\(.*\);.*;.*;.*;.*$/\1/g');
				if [[ $user == $user_name ]]; then 
					echo "[+] The user $user exists."
					return 0
				fi
			done < $file_user
		error 2
		return 1
	fi
}


# Function to verify if the machine exists
function machineCheck { 
    printf "\n[+] Verifying if the machine exists..."
	argCheck $# 1
	if [ $? -eq 0 ]; then
		machine=$1
		while read line
			do
				machine_name=$(echo $line | sed 's/^\(.*\);.*$/\1/g');
				if [ $machine == $machine_name ]; then 
					printf "\n[+] The machine $machine exists."
					return 0
				fi
			done < $file_machine
		error 3
		return 1
	fi
}


# Function to verify the password of the user
function passwordCheck {
	argCheck $# 1
	if [ $? -eq 0 ]; then
		user=$1
		read -sp "Enter the password of $user : " password
		while read line
			do
                user_name=$(echo $line | sed 's/^\(.*\);.*;.*;.*;.*$/\1/g')
				if [ $user == $user_name ] ; then # On trouve le user dans le fichier 
					correct_password=$(echo $line | sed 's/^.*;\(.*\);.*;.*;.*$/\1/g') ; # On récupère le mot de passe correct
					if [ $password == $correct_password ] ; then 
						printf "\n[+] Password correct"
						return 0
					fi
				fi
			done < $file_user
			error 4
			return 1
	fi
}

# Function to verify if the user has access to the machine
function accessCheck {
	printf "\n[+] Verifying if the user has access to the machine..."
	argCheck $# 2
	if [ $? -eq 0 ]; then
		user=$1
		machine=$2
		while read line
			do
				if [ $machine == $(echo $line | sed 's/^\(.*\);.*$/\1/g') ]; then 
					access=$(echo $line | sed 's/^.*;\(.*\)$/\1/g' | sed "s/^.*,$user,.*$/,$user,/g") 
					if [ ",$user," == $access ]; then 
						printf "\n[+] Access granted\n"
						return 0
					fi
				fi
			done < $file_machine
			error 5
			return 1
	fi
}


# Function to check if the user is connected to the machine
function connectedCheck {
	user=$1
	machine=$2

	if [[ $(grep "$user;$machine" $file_connexion) == "" ]] ; then
		error 6
		return 1
	else
		return 0
	fi
}


# Function tp convert a date to a timestamp
function dateToTimestamp {
	timestamp=$(date +%Y%m%d%H%M%S)
	echo "$timestamp"
}


# Function to add a connexion in the connexion file
function addConnexion {
	argCheck $# 2
	if [ $? -ne 0 ]; then
		return 1
	fi

	terminal=$(tty | sed 's/\//_/g')
	user=$1
	machine=$2
	date=$(dateToTimestamp)

	echo "$terminal;$user;$machine;$date" >> $file_connexion
	
}


# Function to remove a connexion in the connexion file
function removeConnexion {
	argCheck $# 2
	if [ $? -ne 0 ]; then
		return 1
	fi

	terminal=$(tty | sed 's/\//_/g')
	user=$1
	machine=$2

	text=$(grep "$terminal;$user;$machine" $file_connexion | tail -1)
	sed -i "/$text/d" $file_connexion
}


# Function to update connexions in the connexion file
function updateConnexion {
	argCheck $# 2
	if [ $? -ne 0 ]; then
		return 1
	fi
	terminal=$(tty | sed 's/\//_/g')
	user=$1
	machine=$2
	date=$(dateToTimestamp)


	machineCheck $machine

	if [ $? -ne 0 ]; then
		return 1
	fi

	text=$(grep "$terminal;$user;$machine" $file_connexion | tail -1)
	
	date=$(dateToTimestamp)

	sed -i "s/$text/$terminal;$user;$machine;$date/" $file_connexion

	return 2
}


function connexion {
	user=$1
	machine=$2

    #Check if the user exists
	userCheck $user
	if [[ $? -ne 0 ]] ; then
		return 1
	fi

	#Check if the password is correct
	passwordCheck $user
	if [[ $? -ne 0 ]] ; then
		return 1
	fi
	
	#Check if the machine exists
	machineCheck $machine
	if [[ $? -ne 0 ]] ; then
		return 1
	fi

	#Check if the user has access to the machine
	accessCheck $user $machine
	if [[ $? -ne 0 ]] ; then
		return 1
	fi

	#Add the connexion in the connexion file
	addConnexion $user $machine


	#Loop to allow the user to enter commands
	while true; 
        do
            read -p "$user@$machine> " command

            if [[ $command == "exit" ]] ; then
                new=$(logout 1 $user $machine)
                if [[ $new == "Out" ]] ; then
                    break
                else
                    user=$(echo $new | cut -d ";" -f 1)
                    machine=$(echo $new | cut -d ";" -f 2)
                fi
            else
                updateConnexion $user $machine
                if [ $? -eq 0 ]; then
                    new=$(logout 1 $user $machine)
                    if [[ $new == "Out" ]] ; then
                        break
                    else
                        user=$(echo $new | cut -d ";" -f 1)
                        machine=$(echo $new | cut -d ";" -f 2)
                    fi
                fi
                commandCall $command
            fi
	    done
}


# Function allowing the user to use a call a command
function commandCall {
	command=$1
	shift
	if [ -z $command ]; then
		echo ""
	else
		case $command in
            who)
                commandWho "$@";;
			*)
				unkownCommand "$@";;
		esac
	fi
}


function unkownCommand {
	echo "Unknown command : $1" 
}


# Function to logout
function logout {
	option=$1
	user=$2
	machine=$3

	printf "Deconnecting from $user@$machine\n\n" 

	if [[ $option -eq 1 ]] ; then
		removeConnexion $user $machine
		if [[ -z $(grep "$(tty | sed 's/\//_/g');" $file_connexion) ]] ; then
			echo "You are going to be deconnected from the machine" 
			echo "Out"
		else 
			newUser=$(grep "$terminal;" $file_connexion | tail -1 | cut -d ";" -f 2)
			newMachine=$(grep "$terminal;" $file_connexion | tail -1 | cut -d ";" -f 3)
			echo "$newUser;$newMachine"
		fi
	elif [[ $option -eq 2 ]] ; then
		if [[ -z $(grep "$(tty | sed 's/\//_/g');" $file_connexion) ]] ; then
			echo "You are going to be deconnected from the machine."
			echo "Out"
		else 
			newUser=$(grep "$terminal;" $file_connexion | tail -1 | cut -d ";" -f 2)
			newMachine=$(grep "$terminal;" $file_connexion | tail -1 | cut -d ";" -f 3)

			if [[ $newMachine != $machine ]] ; then
				echo "The machine $machine does not exist. You are going to be deconnected from the machine."
			elif [[ $newUser != $user ]] ; then
				echo "The user $user does not exist. You are going to be deconnected from the machine."
			fi

			echo "$newUser;$newMachine"
		fi
	fi

}



if [[ $1 == "-admin" ]] ; then
	argCheck $# 1
	if [[ $? -eq 0 ]] ; then
		user="root"
		machine="hostroot"
		connexion $user $machine
	fi
elif [[ $1 == "-connect" ]] ; then
	argCheck $# 3
	if [[ $? -eq 0 ]] ; then
		user=$2
		machine=$3
		connexion $user $machine
	fi
elif [[ $1 == "-help" ]] ; then
    help
else
	error 1
    help
fi