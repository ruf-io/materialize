#!/usr/bin/env bash

# Copyright Materialize, Inc. and contributors. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.
#
# devsite.sh — deploys docs to dev.materialize.com in CI.

set -euo pipefail

aws s3 cp misc/www/index.html s3://materialize-dev-website/index.html

bin/doc
aws s3 sync target/doc/ s3://materialize-dev-website/api/rust

bin/doc --document-private-items
aws s3 sync target/doc/ s3://materialize-dev-website/api/rust-private

bin/pydoc
aws s3 sync target/pydoc/ s3://materialize-dev-website/api/python
