rem A quick way to halt and destroy the VM (for testing this Vagrant configuration).
rem Normally, you wouldn't want to destroy it every time.

cd %~dp0
cmd /k "vagrant halt && vagrant destroy"
