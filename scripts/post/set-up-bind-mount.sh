#! /bin/bash
profile_name=login-hooks
prev=$(authselect current --raw)
prev_profile=$(echo $prev|cut -d' ' -f1)
prev_features=$(echo $prev|cut -d' ' -f2-)
authselect create-profile --vendor $profile_name --symlink-nsswitch --symlink-dconf --base-on=$prev_profile
profile_dir=/usr/share/authselect/vendor/$profile_name
cat >$profile_dir/README <<EOF
Run bind mount on login (otherwise same as $prev_profile profile)
========================================================

SEE ALSO
--------
* $prev_profile profile
EOF

echo 'session     optional                   pam_exec.so /usr/sbin/create-bind-mount' >>$profile_dir/postlogin
authselect select $profile_name $prev_features