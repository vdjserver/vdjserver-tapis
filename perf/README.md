# Performance Testing Directory
---

Performance testing uses data availble from the community data portal in VDJServer.

Each subdirectory contains a python script titled `make_jobs.py` that can be used to generate the json job files. These job files can be submited through `vdjserver-tapis` using the `vdjserver-tools jobs submit <filename>` command. Alternatively, a bash script titled `submit-jobs.sh` can be used instead to automate this process.

All of this functionality can be easily accessed by changing directories to the subdirectory of choice and running `make all` inside a `vdjserver-tapis` docker instance. This will envoke the `make jobs` to create the job files, `make submit` to submit the jobs files, and `make clean` to remove the json job files used.