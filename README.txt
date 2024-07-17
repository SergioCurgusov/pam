Добавляем пользователей:

useradd otusadm
useradd otus

Пример из методички не работает. Не знаю как сдают другие:

root@pam:/home/vagrant# echo "Otus2022!" | passwd --stdin otusadm
passwd: unrecognized option '--stdin'

Потому использую альтернативу:

echo "otusadm:Otus2022!" | chpasswd
echo "otus:Otus2022!" | chpasswd

Создаём группу admin:

groupadd -f admin

Добавляем пользователей vagrant,root и otusadm в группу admin:

usermod otusadm -aG admin
usermod root -aG admin
usermod vagrant -aG admin

После создания пользователей, нужно проверить, что они могут подключаться по SSH к нашей ВМ.
Используя предложенную в методичке конфигурацию, не подключаются!!!
Ищем, в чём подвох. В /etc/ssh/sshd_config.d лежат конфиги, где прописано обратное. Исправляем вагрант-файл и идём дальше.

Далее настроим правило, по которому все пользователи кроме тех, что указаны в группе admin не смогут подключаться в выходные дни:

Проверим, что пользователи есть в группе admin

cat /etc/group | grep admin

Создадим скрипт:

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

nano /etc/pam.d/sshd 

Опять ошибки в методичке: из ничеперечисленного в /etc/pam.d/sshd добавить нужно только "auth required pam_exec.so debug /usr/local/bin/login.sh"

#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
auth required pam_exec.so debug /usr/local/bin/login.sh
account    required     dad
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin

Вносим измнения в vagrantfile.

Теперь проверяем:

через data как в методичке время не меняется. Делаем по-своему.

# отключаем синхронизацию с ntp
sudo timedatectl set-ntp no

# устанавливаем выходной
timedatectl set-time "2024-07-14 20:43:36"

Всё работает:

sergio@sergio-Z87P-D3:/media/VM/pam$ ssh otus@192.168.38.200
otus@192.168.38.200's password: 
Permission denied, please try again.
otus@192.168.38.200's password: 
Permission denied, please try again.
otus@192.168.38.200's password: 
otus@192.168.38.200: Permission denied (publickey,password).

sergio@sergio-Z87P-D3:/media/VM/pam$ ssh otusadm@192.168.38.200
otusadm@192.168.38.200's password: 
Welcome to Ubuntu 22.04.4 LTS (GNU/Linux 5.15.0-113-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Wed Jul 17 20:00:31 UTC 2024

  System load:  0.0               Processes:               112
  Usage of /:   3.9% of 38.70GB   Users logged in:         1
  Memory usage: 21%               IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.


The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

Last login: Sun Jul 14 20:44:19 2024 from 192.168.38.156
Could not chdir to home directory /home/otusadm: No such file or directory
$ 
