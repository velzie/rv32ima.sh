/***********************************************************************
 *                                                                      *
 *               This software is part of the ast package               *
 *          Copyright (c) 1982-2014 AT&T Intellectual Property          *
 *                      and is licensed under the                       *
 *                 Eclipse Public License, Version 1.0                  *
 *                    by AT&T Intellectual Property                     *
 *                                                                      *
 *                A copy of the License is available at                 *
 *          http://www.eclipse.org/org/documents/epl-v10.html           *
 *         (with md5 checksum b35adb5213ca9657e911e9befb180842)         *
 *                                                                      *
 *              Information and Software Systems Research               *
 *                            AT&T Research                             *
 *                           Florham Park NJ                            *
 *                                                                      *
 *                    David Korn <dgkorn@gmail.com>                     *
 *                                                                      *
 ***********************************************************************/
#include "config_ast.h"  // IWYU pragma: keep

#include <stdbool.h>
#include <string.h>

#include "builtins.h"
#include "cdt.h"
#include "defs.h"
#include "error.h"
#include "name.h"
#include "option.h"
#include "shcmd.h"

// The `unset` builtin.
int b_unset(int argc, char *argv[], Shbltin_t *context) {
    UNUSED(argc);
    Shell_t *shp = context->shp;
    Dt_t *troot = shp->var_tree;
    nvflag_t nvflags = 0;
    int n;

    while ((n = optget(argv, sh_optunset))) {
        switch (n) {  //!OCLINT(MissingDefaultStatement)
            case 'f': {
                troot = sh_subfuntree(shp, true);
                nvflags |= NV_NOSCOPE;
                break;
            }
            case 'n': {
                nvflags |= NV_NOREF;
                troot = shp->var_tree;
                break;
            }
            case 'v': {
                troot = shp->var_tree;
                break;
            }
            case ':': {
                errormsg(SH_DICT, 2, "%s", opt_info.arg);
                break;
            }
            case '?': {
                errormsg(SH_DICT, ERROR_usage(0), "%s", opt_info.arg);
                return 2;
            }
        }
    }
    argv += opt_info.index;
    if (error_info.errors || !*argv) {
        errormsg(SH_DICT, ERROR_usage(2), "%s", optusage(NULL));
        __builtin_unreachable();
    }

    if (!troot) return 1;
    if (troot == shp->var_tree) nvflags |= NV_VARNAME;
    return nv_unall(argv, false, nvflags, troot, shp);
}
