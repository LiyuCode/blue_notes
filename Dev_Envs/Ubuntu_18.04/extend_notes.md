
# Keep command running after SSH connection is breaken.
(Reference)[https://serverfault.com/questions/463366/does-getting-disconnected-from-an-ssh-session-kill-your-programs]
Action: uncomment `KillUserProcesses=no` in `/etc/systemd/logind.conf`
