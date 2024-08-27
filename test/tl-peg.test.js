"use strict";

const { testTarget } = require('./abnf-runner.js');
const { tl_peg } = require('../lib/tl-peg.js');
testTarget('peg', tl_peg);
