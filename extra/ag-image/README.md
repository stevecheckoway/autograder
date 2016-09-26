Instructions
============
1. Build docker image: `sudo docker build -t ag-image .`
2. Install `run-ag-image.sh` in `/usr/local/bin`

   ```
   sudo cp run-ag-image.sh /usr/local/bin
   ```

3. Let the `autograder` user run `run-ag-image.sh` with sudo without a
   password. Run `sudo visudo` and insert the following line.

   ```
   autograder ALL=(ALL) NOPASSWD: /usr/local/bin/run-ag-image.sh
   ```

4. Run scripts in the docker image using `docker: ag-image` in the assignment
   YAML file.
