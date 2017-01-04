AutoGrader
==========

Description here!

Notes
=====

Until I get around to making proper documentation, these notes are just to
help me remember what I did.

1. Create a system account `autograder` with a home directory of
   `/var/lib/autograder`
2. Check out the repo as `/var/lib/autograder/autograder`
3. From inside the repo, run `bundle install --binstubs=sbin --path=vendor/bundle`
4. Create `config/secrets.yaml` that looks like:
   ```
   admin_password: 'PASSWORD HERE'
   github_webhooks_secret: 'WEBHOOKS SECRET HERE'
   ORGANIZATION_NAME:
     admin_password: 'PASSWORD HERE'
   ```
   Multiple organizations can be supported, but they currently need the same
   webhooks secret.
5. Install nginx.
6. Modify and install the nginx files in `extra/nginx` in the appropriate
   locations. (The files say where to go.)
7. Configure [Let's Encrypt](https://letsencrypt.org/) to autorenew and make
   sure the certs are being picked up by nginx correctly.
8. [Optional] Install Docker and follow the directions in `extra/ag-ubuntu` for
   building and installing the container and helper scripts.
9. Install the systemd service file in `extra/systemd`, the `init.d` script
   probably doesn't work and should just be deleted.
10. Start nginx and autograder using the `service` command.
11. Create assignment files that look like `project1.yaml`:
    ```
    token:        GITHUB-PERSONAL-ACCESS-TOKEN
    organization: ORGANIZATION-NAME
    assignment:   project-1
    branch:       submission
    repos:
      - testscripts
    docker:       ag-ubuntu
    scriptfile:   testscripts/grade-project1.sh
    codecomment:  true
    ```
