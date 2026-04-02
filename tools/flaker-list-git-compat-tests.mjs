#!/usr/bin/env node

import { listFlakerGitCompatTests } from "./flaker-git-compat-lib.mjs";

console.log(JSON.stringify(listFlakerGitCompatTests(), null, 2));
