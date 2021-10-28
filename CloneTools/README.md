# `db_clone` BigCouch cloning tool

`db_clone` is an erlang tool to copy some or all databases from one Bigcouch cluster to another, with options for pruning CDRs and voicemail during transfer.

## About the utility

1. **NOTE**: Cloning databases may take a very long time (possibly days, depending
on size and service environment). To ensure the execution is not disrupted
consider running in a terminal multiplexer.

2. The proper use case is to run the script, then re-run it immediately BEFORE switching Kazoo to use the TARGET, but NEVER after :)

3. Original development sponsored by CloudPBX Inc. ~ http://cloudpbx.ca;

### Overview: How `db_clone` works

A. Reads all databases on the SOURCE system and starts cloning from that list to the TARGET system.

B. `db_clone` does not overwrite data on TARGET system with the exception of voicemail boxes.

C. Conditional duplication based on database type:

1. If the current db being cloned IS NOT a hashed `account/XX/XX/XXXXX...` db:
  * `db_clone` will get a list of all document IDs in both the SOURCE and TARGET and will then clone any IDs that *only exist* on the SOURCE.

2. If the current db being cloned IS a hashed `account/XX/XX/XXXX...` db then the utility will (in detail):

  * create the database on the TARGET;

  * add a view to the SOURCE db;

  * copy all views to the TARGET (including the newly added "clone" view);

  * Query the clone view for a list of all document IDs that are NOT `cdrs`, `acdc_stats`, `credit`, `debit`, or `vmbox` on both SOURCE and TARGET.  It will then clone any IDs that only exists at the SOURCE.

  * Query the clone view for a list of all documents with attachments on both SOURCE and TARGET.  The results of the view also includes the total size of all attachments on each document.  If this differs then the attachments are copied from the SOURCE to the TARGET.

  * Find all `vmboxes` in SOURCE and OVERWRITE them on the TARGET.

This ensures if a voicemail was left while the clone ran, you can re-run it just prior to the cut over to ensure it is present.  However, this also means if you run this script after a voicemail is left via the TARGET it will be lost.  The proper use case is to run the script, then re-run it immediately BEFORE switching Kazoo to use the TARGET, but NEVER after.

  * [ possibly only CloudPBX related ] query the current available credit in the db and create one transaction on the TARGET to "roll-up" (represent) all the transaction history on the SOURCE.  Note, this is a single document representing the available credit at the time of the clone so the history is lost but since we don't expose it currently this is not an issue unless the client has written a tool to use it themselves.

### How to compile `db_clone`:

```bash
make clean
make
```

### Usage for `db_clone`:

```bash
./db_clone [-s {source}] [-t {target}] \
	[-e {exclude}] \
	[-max_cdr_age ['0||all'|{integer-days}|'none']] \
	[-max_vm_age ['0||all'|{integer-days}|'none']] \
	[-dead_accounts '{list-of-accounts}'] \
	[{databases}]
```

**NOTE:** source and target URLs should end with a trailing slash:  `/`.

- `{source}`: source bigcouch url; default:  `http://127.0.0.1:5984/`
- `{target}`: target bigcouch url; default:  `http://127.0.0.1:15984/`
- `{exclude}`:
    - `modb`: exclude databases matching regexp: `"$account.*-\d{6}$"`
    - `regexp`: exclude databases matching provided regexp
- `max-cdr-age`: maximum age in days for CDRs; `0` is equivalent to `all`, the default is `none`.
- `max-vm-age`: maximum age in days of voicemail messages to clone; `0` is equivalent to `all`, or 'none'.  The default is `0`.
- `list-of-dead-accounts`: a quoted and space separated list of account ids that
  will be excluded from transfer or removed from any `pvt_tree`.
- `{databases}`: a space separated list of database names, unquoted.


### Errata

* `db_clone` creates a one way copy; changes made during the copy will not be
  cloned on subsequent runs with the exception of newly created documents or
  voicemails.

* For the lowest possibility of lost changes the new cluster should be put in service as soon as the clone is complete

* It IS safe to stop and restart the script.

* Caveat: the longer a cloned database is unused the greater a chance changes to the original will be lost.


### Examples

1. Clone all databases from default source to default target.

```bash
./db_clone
```

2. Clone `accounts` and `system_config` databases from `http://source.example.com:5984/` to `http://target.example.com:5984/`

```bash
./db_clone -s http://source.example.com:5984/ -t http://target.example.com:5984/ accounts system_config
```

3. Alternately, clone default source and target, but excluding `accounts` and `system_config` databases via regexp:

```bash
./db_clone -e '^(accounts|system_config)$'
```

3. Clone default source and target, excluding the MODB datasets.

```bash
./db_clone -e modb
```

4. Clone default source and target, duplicating all CDRs and no Voicemails.

```bash
./db_clone -max_cdr_age 0 -max_vm_age none
```

5. Clone default source and target with no exclusions, removing three "dead" accounts.

```bash
./db_clone -dead_accounts "2e0bcf74f7a1b2ce7e408ce2731796a3 544060f3f8af919ad79764ca8a961241 72fabca989b3102c28482c60070aac5b"
```

