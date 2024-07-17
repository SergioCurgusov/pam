#!/bin/bash

sed -i 's/^\#PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
for i in $(ls /etc/ssh/sshd_config.d)
	do
        	sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/$i
        done
systemctl restart sshd.service
useradd otusadm
useradd otus
echo "otusadm:Otus2022!" | chpasswd
echo "otus:123" | chpasswd
groupadd -f admin
usermod otusadm -aG admin
usermod root -aG admin
usermod vagrant -aG admin
cat >> /usr/local/bin/login.sh << EOF
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ \$(date +%a) = "Sat" ] || [ \$(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "\$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
EOF
chmod +x /usr/local/bin/login.sh
echo >> /etc/pam.d/sshd
echo "#%PAM-1.0" >> /etc/pam.d/sshd
echo "auth required pam_exec.so debug /usr/local/bin/login.sh" >> /etc/pam.d/sshd
