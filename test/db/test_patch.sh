

grape-db-setup -c -r -d pg://localhost/grape1.0.8 grape-1.0.8/db/initial.manifest

grape-db-setup -d pg://localhost/grape1.0.8 grape/db/patch/v1.0.9/v1.0.9.manifest

grape-db-setup -c -r -d pg://localhost/grape1.0.9 grape/db/initial.manifest

pg_diff --change_script -t pg://localhost/grape1.0.8 -s pg://localhost/grape1.0.9

