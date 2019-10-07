CREATE DATABASE {{ project }};
CREATE USER {{ project }} WITH PASSWORD '{{ postgres_secret }}';
ALTER ROLE {{ project }} SET client_encoding TO 'utf8';
ALTER ROLE {{ project }} SET default_transaction_isolation TO 'read committed';
ALTER ROLE {{ project }} SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE {{ project }} TO {{ project }};



