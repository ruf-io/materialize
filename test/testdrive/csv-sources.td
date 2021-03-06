# Copyright Materialize, Inc. and contributors. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

$ file-append path=static.csv
city,state,zip
Rochester,NY,14618
New York,NY,10004
"bad,
place""",CA,92679

# We should refuse to create a source with invalid WITH options
! CREATE SOURCE invalid_with_option
  FROM FILE '${testdrive.temp-dir}/static.csv'
  WITH (badoption=true)
  FORMAT CSV WITH 3 COLUMNS
unexpected parameters for CREATE SOURCE: badoption

# Static CSV without headers.
> CREATE MATERIALIZED SOURCE static_csv
  FROM FILE '${testdrive.temp-dir}/static.csv'
  FORMAT CSV WITH 3 COLUMNS

> SELECT * FROM static_csv
column1        column2  column3  mz_line_no
--------------------------------------------
city           state     zip     1
Rochester      NY        14618   2
"New York"     NY        10004   3
"bad,\nplace\""  CA        92679   4

# The timestamp chosen when reading from a static CSV should be the end of time,
# since the definition of "static" means "will never change again".
> SELECT count(*), mz_logical_timestamp() FROM static_csv
4  18446744073709551615

# Static CSV with automatic headers.
> CREATE MATERIALIZED SOURCE static_csv_header
  FROM FILE '${testdrive.temp-dir}/static.csv'
  FORMAT CSV WITH HEADER

> SELECT * FROM static_csv_header
city           state     zip     mz_line_no
--------------------------------------------
Rochester      NY        14618   1
"New York"     NY        10004   2
"bad,\nplace\""  CA        92679   3

# Static CSV with manual headers.
> CREATE MATERIALIZED SOURCE static_csv_manual_header (city_man, state_man, zip_man)
  FROM FILE '${testdrive.temp-dir}/static.csv'
  FORMAT CSV WITH HEADER

> SELECT * FROM static_csv_manual_header
city_man       state_man  zip_man  mz_line_no
---------------------------------------------
Rochester      NY         14618    1
"New York"     NY         10004    2
"bad,\nplace\""  CA         92679    3

# Dynamic CSV with automatic headers.

$ file-append path=dynamic.csv
city,state,zip

> CREATE MATERIALIZED SOURCE dynamic_csv
  FROM FILE '${testdrive.temp-dir}/dynamic.csv' WITH (tail = true)
  FORMAT CSV WITH HEADER

> SELECT * FROM dynamic_csv

$ file-append path=dynamic.csv
Rochester,NY,14618

> SELECT * FROM dynamic_csv
city           state     zip     mz_line_no
--------------------------------------------
Rochester      NY        14618   1

$ file-append path=dynamic.csv
New York,NY,10004

> SELECT * FROM dynamic_csv
city           state     zip     mz_line_no
--------------------------------------------
Rochester      NY        14618   1
"New York"     NY        10004   2

$ file-append path=deleting.csv
city,state,zip
Tucson,AZ,85719

> CREATE SOURCE deleting_csv
  FROM FILE '${testdrive.temp-dir}/deleting.csv'
  FORMAT CSV WITH HEADER

$ file-delete path=deleting.csv

> CREATE INDEX i ON deleting_csv(city,state,zip)

! SELECT * FROM deleting_csv
Source error: materialize.public.deleting_csv: file IO: file source: unable to open file at path

! CREATE SOURCE should_fail FROM FILE '/'
/ is a directory.

# Static malformed CSV
$ file-append path=malformed.csv
Dollars,Category
5161669,Clothing&Shoes
1000000000
,badrow
badint,

> CREATE MATERIALIZED SOURCE malformed_csv
  FROM FILE '${testdrive.temp-dir}/malformed.csv'
  FORMAT CSV WITH HEADER

! SELECT * FROM malformed_csv
Decode error: Text: CSV error at record number 3: expected 2 columns, got 1.

# Static non-utf-8 CSV
$ file-append path=bad-text.csv
Dollars,Category
5161669,\x80

> CREATE MATERIALIZED SOURCE bad_text_csv
  FROM FILE '${testdrive.temp-dir}/bad-text.csv'
  FORMAT CSV WITH HEADER

! SELECT * FROM bad_text_csv
Decode error: Text: CSV error at record number 2: invalid UTF-8
