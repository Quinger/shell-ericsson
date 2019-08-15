#!/bin/bash

export input_dir="/home/ansible/MDC1/idam"
export output_dir="/home/ansible/MDC1/idam"
export ldap1_file=`ls $input_dir/*281.p12`
export ldap2_file=`ls $input_dir/*282.p12`
export ldapmin_file=`ls $input_dir/ldapadmin*.p12`
export ldap1_pw="uCoGOK7UQ2s74ACr"
export ldap2_pw="hWDkrZMJTwqiZjaZ"
export ldapmin_pw="sraYwZkKm2wNfk2"

function install_expect () {
    sudo apt-get install expect -y &> /dev/null
}

function remove_expect () {
    sudo apt-get remove expect -y &> /dev/null
}

function generate_keys () {
    expect -c "
        spawn openssl pkcs12 -in $ldap1_file -out $output_dir/slapd1.key -nocerts -nodes
        expect {
            \"*assword:\" {set timeout -1; send \"$ldap1_pw\n\";}
        }
    expect eof"

    expect -c "
        spawn openssl pkcs12 -in $ldap2_file -out $output_dir/slapd2.key -nocerts -nodes
        expect {
            \"*assword:\" {set timeout -1; send \"$ldap2_pw\n\";}
        }
    expect eof"

    expect -c "
        spawn openssl pkcs12 -in $ldapmin_file -out $output_dir/apache2.key -nocerts -nodes
        expect {
            \"*assword:\" {set timeout -1; send \"$ldapmin_pw\n\";}
        }
    expect eof"

    expect -c "
        spawn openssl pkcs12 -in $ldap1_file -out $output_dir/slapd1.pem -clcerts -nokeys
        expect {
            \"*assword:\" {set timeout -1; send \"$ldap1_pw\n\";}
        }
    expect eof"

    expect -c "
        spawn openssl pkcs12 -in $ldap2_file -out $output_dir/slapd2.pem -clcerts -nokeys
        expect {
            \"*assword:\" {set timeout -1; send \"$ldap2_pw\n\";}
        }
    expect eof"

    expect -c "
        spawn openssl pkcs12 -in $ldapmin_file -out $output_dir/apache2.pem -clcerts -nokeys
        expect {
            \"*assword:\" {set timeout -1; send \"$ldapmin_pw\n\";}
        }
    expect eof"
}

function test_idamfile () {
    ls $output_dir/{slapd*,apache2*}
    for i in `ls $output_dir/{slapd*,apache2*}`
    do
       if [ -s "$i" ]
       then
           echo "$i Pass"
       else
           echo "$i Failed"
           exit 2
       fi
    done
}

function test_md5 () {
    ldap1_keymd5=`openssl rsa -noout -modulus -in $output_dir/slapd1.key | openssl md5`
    ldap1_pemmd5=`openssl x509 -noout -modulus -in $output_dir/slapd1.pem | openssl md5`
    ldap2_keymd5=`openssl rsa -noout -modulus -in $output_dir/slapd2.key | openssl md5`
    ldap2_pemmd5=`openssl x509 -noout -modulus -in $output_dir/slapd2.pem | openssl md5`
    apache2_keymd5=`openssl rsa -noout -modulus -in $output_dir/apache2.key | openssl md5`
    apache2_pemmd5=`openssl x509 -noout -modulus -in $output_dir/apache2.pem | openssl md5`

    if [[ "$ldap1_keymd5" == "$ldap1_pemmd5" && "$ldap2_keymd5" == "$ldap2_pemmd5" && "$apache2_keymd5" == "$apache2_pemmd5" ]]
    then
        echo "md5 success"
    else
        echo "md5 failed"
        exit 1
    fi
}

function copy_keys () {
    ldapfile_dir="/home/ansible/ansible/roles/idam/files/secret"
    time_dir=`date "+%Y%m%d%H%M"`
    echo $time_dir
    dirlist="cs-idam-ldap1
cs-idam-ldap2"
    for i in $dirlist
    do
        create_dir=$ldapfile_dir/$i/$time_dir
        if [ ! -d $create_dir ]
        then
            echo $create_dir
            mkdir $create_dir
            mv $ldapfile_dir/$i/{slapd*,apache2*} $create_dir
            if [ $i == "cs-idam-ldap1" ]
            then
                cp $output_dir/slapd1.key $ldapfile_dir/$i/slapd.key
                cp $output_dir/slapd1.pem $ldapfile_dir/$i/slapd.pem
                cp $output_dir/apache2.key $ldapfile_dir/$i/
                cp $output_dir/apache2.pem $ldapfile_dir/$i/
            elif [ $i == "cs-idam-ldap2" ]
            then
                cp $output_dir/slapd2.key $ldapfile_dir/$i/slapd.key
                cp $output_dir/slapd2.pem $ldapfile_dir/$i/slapd.pem
                cp $output_dir/apache2.key $ldapfile_dir/$i/
                cp $output_dir/apache2.pem $ldapfile_dir/$i/
            fi
        fi
    done
}


function run_playbook () {
    ansible-playbook /home/ansible/ansible/playbooks/current/cs_idam.yml -l cs-idam-ldap*,cs-idam-tacacs* --diff
}

function restart_service () {
    ansible cs-idam-ldap* -m shell -a 'sudo service slapd restart && sudo service slapd status;sudo serivce apache2 restart && sudo serivce apache2 status'
}

function test_ldapsync () {
    ansible cs-idam-ldap* -m shell -a 'sudo /usr/local/sbin/ldap_sync_check.sh'
}

install_expect
#remove_expect
generate_keys
test_idamfile
test_md5
copy_keys
#run_playbook
#restart_service
#test_ldapsync
