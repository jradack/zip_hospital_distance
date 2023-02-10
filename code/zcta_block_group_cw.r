# This script checks if there's a 1:n mapping for ZCTA and block groups
# The final line shows that since there are block groups showing up more
# than once that they do not map to unique ZCTA.

library(data.table)

zcta_cb_cw <- fread("data/raw/tab20_zcta520_tabblock20_natl.txt",
                                colClasses = c(rep("character",3), rep("numeric",2),
                                               rep("character",6), rep("numeric",2),
                                               rep("character",2), rep("numeric",2)),
                                select = c("GEOID_ZCTA5_20", "GEOID_TABBLOCK_20"))

zcta_cb_cw_pa <- zcta_cb_cw[substr(GEOID_TABBLOCK_20,1,2) == '42',]
zcta_cb_cw_pa <- zcta_cb_cw_pa[,GEOID_BLOCKGROUP_20 := substr(GEOID_TABBLOCK_20, 1, 12)]
keep_cols <- c("GEOID_ZCTA5_20", "GEOID_BLOCKGROUP_20")
zcta_cb_cw_pa <- zcta_cb_cw_pa[, keep_cols, with = FALSE]
zcta_cb_cw_pa <- unique(zcta_cb_cw_pa)
max(table(zcta_cb_cw_pa$GEOID_BLOCKGROUP_20))

