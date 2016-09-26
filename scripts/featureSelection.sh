#!/bin/bash

#run model on the lsf cluster
source /import/shared/lang/R/R-3.1.2/setup.sh
/import/transfer/user/ddgrap/PAC_submission/scripts/08_featureSelection.R 

# bsub -q long -n 15 -R "rusage[mem=80000] span[hosts=1]" -M 80971520 \
# -o /import/transfer/user/ddgrap/PAC_submission/results/1.out \
# -e /import/transfer/user/ddgrap/PAC_submission/results/1.err \
# /import/transfer/user/ddgrap/PAC_submission/scripts/featureSelection.sh