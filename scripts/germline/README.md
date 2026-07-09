# Building the IG germline database
Go into germline folder and run the docker command below. Then use the **build_human_IG_germline_db_v2.sh** file to generate the database.

```
docker run -it -v $(pwd):/data:z immcantation/suite:4.5.0 bash
./build_human_IG_germline_db_v2.sh
```
This will create and save the database archive as: **db.2026.07.09.tgz**
---
