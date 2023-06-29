#Function to convert a timestamp to a date
function timeStampToDate {
    timestamp=$1
    year=${timestamp:0:4}
    month=${timestamp:4:2}
    day=${timestamp:6:2}
    hour=${timestamp:8:2}
    minute=${timestamp:10:2}
    second=${timestamp:12:2}

    date_string="$year-$month-$day $hour:$minute:$second"
    readable_date=$(date -d "$date_string" +"%Y-%m-%d %H:%M:%S")
    echo $readable_date
}

#Function to access to the list of users connected to a machine
function commandWho {
    argCheck $# 0
    if [ $? -ne 0 ]; then
        return 1
    fi

    while IFS=';' read -r terminal user machine date; do
        printf "\nUser $user connected on $machine at the date $date"
    done < $file_connexion
}

