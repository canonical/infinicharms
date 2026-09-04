Charm name: myblog

Purpose: The charm operates a simple web server.

Shape:
- Manages the web server in a container. OCI is specified at deploy-time.
- Requires a PostgreSQL database.
- Has a config option for the port, which maps to an environment variable `SERVER_PORT` in the container.
