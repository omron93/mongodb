MongoDB Docker image
====================

This repository contains Dockerfiles for MongoDB images for general usage and OpenShift.
Users can choose between RHEL and CentOS based images.

Environment variables
---------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker run command.

|    Variable name          |    Description                              |
| :------------------------ | -----------------------------------------   |
|  `MONGODB_ADMIN_PASSWORD` | Password for the admin user                 |

Optionally you can provide settings for user with 'readWrite' role.
(Note you MUST specify all three of these settings)

|    Variable name          |    Description                              |
| :------------------------ | -----------------------------------------   |
|  `MONGODB_USER`           | User name for MONGODB account to be created |
|  `MONGODB_PASSWORD`       | Password for the user account               |
|  `MONGODB_DATABASE`       | Database name                               |


The following environment variables influence the MongoDB configuration file. They are all optional.

|    Variable name      |    Description                                                            |    Default
| :-------------------- | ------------------------------------------------------------------------- | ----------------
|  `MONGODB_QUIET`      | Runs MongoDB in a quiet mode that attempts to limit the amount of output. |  true


You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point         | Description            |
| :-------------------------- | ---------------------- |
|  `/var/lib/mongodb/data`   | MongoDB data directory |

**Notice: When mounting a directory from the host into the container, ensure that the mounted
directory has the appropriate permissions and that the owner and group of the directory
matches the user UID or name which is running inside the container.**


Usage
---------------------------------

For this, we will assume that you are using the `centos/mongodb-32-centos7` image.
If you want to set only the mandatory environment variables and store the database
in the `/home/user/database` directory on the host filesystem, execute the following command:

```
$ docker run -d -e MONGODB_USER=<user> -e MONGODB_PASSWORD=<password> -e MONGODB_DATABASE=<database> -e MONGODB_ADMIN_PASSWORD=<admin_password> -v /home/user/database:/var/lib/mongodb/data centos/mongodb-32-centos7
```



Database users
---------------------------------

If you are initializing the database and it's the first time you are using the
specified shared volume, the database will be created with two users: `admin` and `MONGODB_USER`. After that the MongoDB daemon
will be started. If you are re-attaching the volume to another container, the
creation of the database user and admin user will be skipped, password of users will be changed and the
MongoDB daemon will be started.

#### MongoDB admin user

The admin user name is set to `admin` and you have to to specify the password by
setting the `MONGODB_ADMIN_PASSWORD` environment variable.

This user has 'dbAdminAnyDatabase', 'userAdminAnyDatabase', 'readWriteAnyDatabase', 'clusterAdmin' roles (for more information see [MongoDB reference](https://docs.mongodb.com/manual/reference/built-in-roles/)).

#### Optional unprivileged user

The user with `$MONGODB_USER` name is created in database `$MONGODB_DATABASE` and
you have to to specify the password by setting the `MONGODB_PASSWORD` environment variable.

This user has only 'readWrite' role in the database.


#### Changing passwords

Since passwords are part of the image configuration, the only supported method
to change passwords for the database user (`MONGODB_USER`) and admin user is by
changing the environment variables `MONGODB_PASSWORD` and
`MONGODB_ADMIN_PASSWORD`, respectively.

Changing database passwords directly in MongoDB will cause a mismatch between
the values stored in the variables and the actual passwords. Whenever a database
container starts it will reset the passwords to the values stored in the
environment variables.


Extending image
---------------------------------
This image can be extended using [source-to-image](https://github.com/openshift/source-to-image).

For example to build customized MongoDB database image `my-mongodb-centos7` with configuration in `~/image-configuration/` run:

```
$ s2i build ~/image-configuration/ centos/mongodb-32-centos7 my-mongodb-centos7
```

The directory passed to `s2i build` should contain one or more of the following directories::
- `mongodb-cfg/`
  - when running `run-mongod` or `run-mongod-replication` commands contained `mongod.conf` file is used for `mongod` configuration
    - `envsubst` command is run on this file to still allow customization of the image using environment variables
    - custom configuration file does not affect name of replica set - it has to be set in `MONGODB_REPLICA_NAME` environment variable
    - it is not possible to configure SSL using custom configuration file

- `mongodb-pre-init/`
  - contained shell scripts (`*.sh`) are sourced before `mongod` server is started

- `mongodb-init/`
  - contained shell scripts (`*.sh`) are sourced when `mongod` server is started
    - in this phase `mongod` server don't have enabled authentication when running `run-mongod` command (for `run-mongod-replication` command configured users are already created and authentication is enabled)

During `s2i build` all provided files are copied into `/opt/app-root/src` directory in the new image. If some configuration files are present in destination directory, files with the same name are overwritten. Also only one file with the same name can be used for customization and user provided files are preferred over default files in `/usr/share/container-scripts/mongodb/`- so it is possible to overwrite them.

Same configuration directory structure can be used to customize the image every time the image is started using `docker run`. The directory have to be mounted into `/opt/app-root/src/` in the image (`-v ./image-configuration/:/opt/app-root/src/`). This overwrites customization built into the image.

Mounting custom configuration file
---------------------------------

It is allowed to use custom configuration file for `mongod` server. To use it in container it has to be mounted into `/etc/mongod.conf`. For example to use configuration file stored in `/home/user` directory use this option for `docker run` command: `-v /home/user/mongod.conf:/etc/mongod.conf:Z`.

For more information see description of `mongodb-cfg/` directory in section about extending image using s2i.
