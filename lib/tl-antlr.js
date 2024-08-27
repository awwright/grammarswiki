"use strict";

const { tl } = require('./tl.js');

/* A standard interface to hook into the features of many other kinds of parser generators */
class tl_chevrotain extends tl {
    
    /*  */
    static translateABNF(abnf){
        throw new Error('Unimplemented');
    }
    
    /* */
    test(input){

    }
}

