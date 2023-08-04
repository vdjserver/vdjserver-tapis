systems
=======
Tapis V3 storage and execution systems for VDJServer.

Generally the system only needs to be created and setup once.

When setting up a new system, first define a test system and go through
all the steps to insure it works. This is important because systems IDs
are permanent, cannot be re-used after deletion, and errors will cause
the system to be unusable and not-updatable. We learned this the
hard way with `data.vdjserver.org` which is now a useless system.

To list the systems:

```
curl -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems?select=allAttributes
```

To create a new system:

```
curl -X POST -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems -d @json_file
```

To update an existing system, note that the system id is part of the URL:

```
curl -X PUT -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems/<system_id> -d @json_file
```

After creating a system, need to define credentials for the `vdj` account. You will need the ssh private
and public keys for the vdj account on the system. There are credentials files, listed below, that
contain the public key. Insert the private key into the file and define the credentials, then delete
the private key from the file when you are done.

DO NOT COMMIT FILES WITH PRIVATE KEYS! The private keys will then be available for anybody
to view in git. If you accidentally do so, you must create new keys on the system and update
the credentials for the system. Be sure to delete all instances of the comprised keys from
Tapis and from any computers so they do not get mistakenly used in the future.

If it is a new system then you can create a new public/private set of keys:

```
ssh-keygen -t rsa -b 4096 -m PEM
```

The private key has to be on a single line, and this command will help but be sure to remove
the command line prompt from the end of it:

```
cat id_rsa | awk -v ORS='\\n' '1'
```

To add credentials for the vdj account for the system, note that the system id is part of the URL:

```
curl -X POST -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems/credential/<system_id>/user/vdj -d @json_file
```

If the system and credentials are defined properly, you should be able to list files on the system:

```
curl -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/files/ops/<system_id> | jq
```

A system can be deleted but the id cannot be re-used. Deleting a system just removes it
from queries...

credentials
===========

* vdj-rep-01.credentials.json: credentials for vdj-rep-01 system, used as Corral storage proxy

storage
=======

* test-data.vdjserver.org.json: test storage system
* data-storage.vdjserver.org.json: production storage system

execution
=========

