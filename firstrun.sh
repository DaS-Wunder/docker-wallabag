#!/bin/bash


#########################################################
#							#
# 	Helper function for reading config file 	#
#							#			
#########################################################


#read one given variable from config file or set it by itself, but report if it is in the config or not
function readConfigFileVariable(){

local CONFIG_FILE="wallabagConfig.cfg"
local CONFIG_DTD_FILE="wallabagCredentials.dtd"


local STATUS=$1
local RETURN_VALUE=""

local VARIABLE_WAS_IN_CONFIG_FILE=1

if [ -f $CONFIG_FILE ]; then
	XML_CHECK=$(xmlstarlet val -e -d  $CONFIG_DTD_FILE $CONFIG_FILE  2>&1)

	if [[ $XML_CHECK == *"invalid"* ]];  then
		echo "Error in your $CONFIG_FILE "
		echo "$XML_CHECK"
		exit 1
	else
		case $STATUS in
		"DB_WALLABAG_USER") 	RETURN_VALUE=$(xmlstarlet sel -t -v "/credentials/mariadb/username" $CONFIG_FILE);;
		"DB_PASSWORD") 		RETURN_VALUE=$(xmlstarlet sel -t -v "/credentials/mariadb/password" $CONFIG_FILE);;
		"WALLABAG_USER") 	RETURN_VALUE=$(xmlstarlet sel -t -v "/credentials/wallabag/username" $CONFIG_FILE);;
		"WALLABAG_PASSWORD") 	RETURN_VALUE=$(xmlstarlet sel -t -v "/credentials/wallabag/password" $CONFIG_FILE);;
		"SALT") 		RETURN_VALUE=$(xmlstarlet sel -t -v "/credentials/wallabag/salt" $CONFIG_FILE);;
		*)			echo "Something went terrible wrong. Exiting program"; exit 1;;
		esac

		if [ -z $RETURN_VALUE ]; then
			VARIABLE_WAS_IN_CONFIG_FILE=0
		fi

	fi
else
	VARIABLE_WAS_IN_CONFIG_FILE=0

fi


#If the config fiel has no attribute with the element or there is no config file, new data will be created
if [  $VARIABLE_WAS_IN_CONFIG_FILE -eq 0 ]; then

		case $STATUS in
		"DB_WALLABAG_USER") 	RETURN_VALUE="wallabag";;
		"DB_PASSWORD") 		RETURN_VALUE=`pwgen -s -1 10`;;
		"WALLABAG_USER") 	RETURN_VALUE="wallabag";;
		"WALLABAG_PASSWORD") 	RETURN_VALUE="wallabag";;
		"SALT") 		RETURN_VALUE=$(date|md5sum| cut -d " " -f1);;
		*)			echo "Something went terrible wrong. Exiting program"; exit 1;;
		esac

fi

CONFIG_FILE_ARRAY=($RETURN_VALUE $VARIABLE_WAS_IN_CONFIG_FILE)

}


#function with one parameter which says if all variables has to be in the config file or not
#param 0 -- all variable has NOT to be in the config file 
#param 1 -- all variable has to be in the config file 
function readAllConfigFileVariables(){


#########################################################
#							#
# 	Get all needed variables			#
#							#
#########################################################


local ALL_VARIABLES_HAS_TO_BE_IN_THE_CONFIG_FILE=$1

readConfigFileVariable DB_WALLABAG_USER
DB_WALLABAG_USER=${CONFIG_FILE_ARRAY[0]} 
if [ $ALL_VARIABLES_HAS_TO_BE_IN_THE_CONFIG_FILE -eq 1 ]  && [  ${CONFIG_FILE_ARRAY[1]} -eq 0 ]; then
	return 0
fi

readConfigFileVariable DB_PASSWORD
DB_PASSWORD=${CONFIG_FILE_ARRAY[0]} 
if [ $ALL_VARIABLES_HAS_TO_BE_IN_THE_CONFIG_FILE -eq 1 ] && [ ${CONFIG_FILE_ARRAY[1]} -eq 0 ]; then
	return 0
fi

readConfigFileVariable WALLABAG_USER
WALLABAG_USER=${CONFIG_FILE_ARRAY[0]} 
if [ $ALL_VARIABLES_HAS_TO_BE_IN_THE_CONFIG_FILE -eq 1 ] && [ ${CONFIG_FILE_ARRAY[1]} -eq 0 ]; then
	return 0
fi

readConfigFileVariable WALLABAG_PASSWORD
WALLABAG_PASSWORD=${CONFIG_FILE_ARRAY[0]} 
if [ $ALL_VARIABLES_HAS_TO_BE_IN_THE_CONFIG_FILE -eq 1 ] && [ ${CONFIG_FILE_ARRAY[1]} -eq 0 ]; then
	return 0
fi

readConfigFileVariable SALT
SALT=${CONFIG_FILE_ARRAY[0]} 
if [ $ALL_VARIABLES_HAS_TO_BE_IN_THE_CONFIG_FILE -eq 1 ] && [ ${CONFIG_FILE_ARRAY[1]} -eq 0 ]; then
	return 0
fi


return 1
}



#create the php config file for wallabag
createWallabagConfigFile(){

#########################################################
#							#
# 	Create wallabag config file			#
#							#
#########################################################
CONFIG_DIR="/var/www/wallabag/inc/poche"
CONFIG_FILE="config.inc.php"
cd $CONFIG_DIR
#cp inc/poche/config.inc.default.php inc/poche/config.inc.php
cp config.inc.default.php config.inc.php

#set salt
sed -i -e  's#\(.*'\''SALT'\'',\)\(.*\)#\1'\'''"${SALT}"''\''\);#g' $CONFIG_FILE

#replace sqlite with mysql and replace user and databasename to wallabag
sed -i -e  's#\(.*'\''STORAGE'\'',\)\(.*\)#\1'\''mysql'\''\);#g' $CONFIG_FILE
sed -i -e  's#\(.*'\''STORAGE_DB'\'',\)\(.*\)#\1'\''wallabag'\''\);#g' $CONFIG_FILE
sed -i -e  's#\(.*'\''STORAGE_USER'\'',\)\(.*\)#\1'\'''"${DB_WALLABAG_USER}"''\''\);#g' $CONFIG_FILE

#mysql use utf8
sed -i -e  's#\(.*'\''MYSQL_USE_UTF8MB4'\'',\)\(.*\)#\1'\''TRUE'\''\);#g' $CONFIG_FILE

#set password
sed -i -e  's#\(.*'\''STORAGE_PASSWORD'\'',\)\(.*\)#\1'\'''"${DB_PASSWORD}"''\''\);#g' $CONFIG_FILE

#set right permissions for the config file
chown www-data:www-data config.inc.php

}

#########################################################
#							#
# 	Test if database and wallabag config already 	#
#	already exists					#
#							#			
#########################################################




WALLABAG_DATABASE_EXISTS=0
WALLABAG_CONFIG_FILE_EXISTS=0

if [ -f /config/databases/wallabag/users.ibd ]; then
	WALLABAG_DATABASE_EXISTS=1
fi


if [ -f /var/www/wallabag/inc/poche/config.inc.php ]; then
	WALLABAG_DATABASE_EXISTS=1
fi



#########################################################
#							#
# 	If a config file exists and also a database 	#
#	then a new wallabag config is written. 		#
#		Else no changes were made.		#
#	If no database exists a config will be read	#			
#	for user credentials. If there is none, new 	#
#	parameter will be created and written in a new	#			
#	config file for the user.			#
#		After that a new database and wallabag	#			
#		config file will be created		#			
#							#			
#########################################################


DB_WALLABAG_USER=""
DB_PASSWORD=""
WALLABAG_USER=""
WALLABAG_PASSWORD=""
SALT=""


if [  $WALLABAG_DATABASE_EXISTS -eq 1 ]; then
	if [ $WALLABAG_CONFIG_FILE_EXISTS -eq 1 ]; then
		echo "Everything is fine. Using your old data."
	elif [ -f $CONFIG_FILE ]; then
		echo "Creating new Wallabag config file"

		readAllConfigFileVariables 1		
		ARE_ALL_VARIABLES_AVAILABLE=$?


		if [ $ARE_ALL_VARIABLES_AVAILABLE -eq 0 ]; then
			echo "Error: Not all needed data was found in your configuration file.
				Cannot create Wallabag config file.
				Please check if database username and password and
				wallabag username,password and salt are given."
		else
			
			createWallabagConfigFile 	
			echo "Success: Wallabag config file was created."
		fi
			
	else
		echo "Error: Cannot create Wallabag config file, because there is no
			wallabagCredentials.cfg where i can read the credentials from
			for your existing mariadb database."
	fi
else

		#########################################################
		#							#
		# 	Read config file for wallabag and mariadb	#
		#							#				
		#########################################################

		#Read Config File
		readAllConfigFileVariables 0
		
		#########################################################
		#							#
		# 	Create config file with all used values		#
		#	named wallabagConfig.save			#					
		#							#
		#########################################################

		WALLABAG_SAVE_FILE="/config/wallabagConfig.save"
		touch $WALLABAG_SAVE_FILE
		echo "<credentials>
			<wallabag></wallabag>
			<mariadb></mariadb>
			</credentials>" > $WALLABAG_SAVE_FILE

		xmlstarlet ed --inplace -s credentials/mariadb -t elem -n username -v $DB_WALLABAG_USER   $WALLABAG_SAVE_FILE 
		xmlstarlet ed --inplace -s credentials/mariadb -t elem -n password -v $DB_PASSWORD   $WALLABAG_SAVE_FILE

		xmlstarlet ed --inplace -s credentials/wallabag -t elem -n username -v $WALLABAG_USER   $WALLABAG_SAVE_FILE
		xmlstarlet ed --inplace  -s credentials/wallabag -t elem -n password -v $WALLABAG_PASSWORD   $WALLABAG_SAVE_FILE
		xmlstarlet ed --inplace -s credentials/wallabag -t elem -n salt -v $SALT   $WALLABAG_SAVE_FILE



		#########################################################
		#							#
		# 	Create mariadb for wallabag			#
		#							#
		#########################################################
		# If databases do not exist, create them

		start_mysql(){
		    /usr/bin/mysqld_safe --datadir=/config/databases > /dev/null 2>&1 &
		    RET=1
		    while [[ RET -ne 0 ]]; do
			mysql -uroot -e "status" > /dev/null 2>&1
			RET=$?
			sleep 1
		    done
		}

		start_nginx(){
			echo "Try Starting nginx and php5-fpmi"
		   service php5-fpm start
		    /usr/sbin/nginx -c /etc/nginx/nginx.conf 2>&1 &
		    RET=""
		    while [[ -z "$RET"  ]]; do
			RET=$(ps waux | grep nginx | grep -i master)
			sleep 1
		    done
		}
		stop_nginx(){
			echo "Stopping nginx"
			/usr/sbin/nginx -s stop
			service php5-fpm stop
			sleep 3
		}


		if [ -f /config/databases/wallabag ]; then
			echo "Database exists."
		else
			echo "Initializing Data Directory."
			/usr/bin/mysql_install_db --datadir=/config/databases >/dev/null 2>&1
			echo "Installation complete."
			start_mysql
			echo "Creating user and database."
			mysql -uroot -e "CREATE DATABASE IF NOT EXISTS wallabag DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"

		#| sed -r 's/.*(.{34})/\1/;s/.{2}$//')

			mysql -uroot -e "CREATE USER '$DB_WALLABAG_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'"
			echo "Database created. Granting access to '$DB_WALLABAG_USER' user for localhost."
			mysql -uroot wallabag < /var/www/wallabag/install/mysql.sql
			mysql -uroot -e "GRANT ALL PRIVILEGES ON wallabag.* TO '$DB_WALLABAG_USER'@'localhost'"
			mysql -uroot -e "FLUSH PRIVILEGES"

			start_nginx
			CURL_DB_DATA="db_engine=mysql&mysql_server=localhost&mysql_database=wallabag&mysql_user=$DB_WALLABAG_USER&mysql_password=$DB_PASSWORD&mysql_utf8_mb4=on"
			CURL_WALLABAG_DATA="username=$WALLABAG_USER&password=$WALLABAG_PASSWORD&email=''&install=Install+wallabag"
			echo "Execute Wallabag install script"
			curl -s -d $CURL_WALLABAG_DATA  -d $CURL_DB_DATA  http://localhost > /dev/null
			stop_nginx

			echo "Shutting down."
			mysqladmin -u root shutdown
			sleep 3
			echo "chown /config/databases"
			chown -R nobody:users /config/databases
			chmod -R 755 /config/databases
			sleep 3
			echo "Initialization complete."
		fi


		#########################################################
		#							#
		# 	Create wallabag config file			#
		#							#
		#########################################################
		 
#			createWallabagConfigFile 	
			echo "Succesfull: Wallabag config was created successfully"	
	
			echo "Removing wallabag install directory."
			rm -R /var/www/wallabag/install
fi






