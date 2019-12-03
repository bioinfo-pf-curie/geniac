## rna.inc.sh
## Functions of RNA-seq pipeline
##
## Copyright (c) 2017-2018 Institut Curie
## Author(s): Nicolas Servant
## Contact: nicolas.servant@curie.fr
## This software is distributed without any guarantee under the terms of the BSD-3 licence.
## See the LICENCE file for details
##
##
##
##
## GLOBAL VARIABLE ARE WRITTEN IN UPPER CASE
## local variable are written in lower case
rseq_output_file=$1

## $1 reseqc output
parse_rseqc_output()
{
    rseqout=$1
    ret="undetermined"

    if [ ! -e $rseqout ]; then
        die "File $rseqout was not find ! Exit"
    fi

    ##PE
    if [[ $(grep -c "PairEnd" $rseqout) -ne 0 ]]; then
	nb_fail=$(grep "failed" $rseqout | awk -F": " '{print $2}')
	nb_fs=$(echo "$nb_fail > 0.5" | bc)
	if [ $nb_fs -eq 1 ]; then ret="undetermined"; fi

	nb_fr=$(grep "1++" $rseqout | awk -F": " '{print $2}') ## fr-secondstrand = yes = forward
	nb_rf=$(grep "2++" $rseqout | awk -F": " '{print $2}') ## fr-firststrand = reverse

	if [[ ! -z $nb_fr && ! -z $nb_rf ]]; then
	    nb_yes=$(echo "$nb_fr - $nb_rf > 0.5" | bc)
	    nb_rev=$(echo "$nb_fr - $nb_rf < -0.5" | bc)
	    
	    if [ $nb_rev -eq 1 ];then
		ret="reverse"
	    elif [ $nb_yes -eq 1 ];then
		ret="forward"
	    else
		ret="no"
	    fi
	fi
    else
    ##SE
	nb_fail=$(grep "failed" $rseqout | awk -F": " '{print $2}')
        nb_fs=$(echo "$nb_fail > 0.5" | bc)
        if [ $nb_fs -eq 1 ]; then ret="undetermined"; fi

        nb_ss=$(grep "++" $rseqout | awk -F": " '{print $2}') ## fr-secondstrand = yes = forward
        nb_ds=$(grep "+-" $rseqout | awk -F": " '{print $2}') ## fr-firststrand = reverse

        if [[ ! -z $nb_ss && ! -z $nb_ds ]]; then
	    nb_yes=$(echo "$nb_ss - $nb_ds > 0.5" | bc)
            nb_rev=$(echo "$nb_ss - $nb_ds < -0.5" | bc)
	
            if [ $nb_rev -eq 1 ]; then
		ret="reverse"
            elif [ $nb_yes -eq 1 ];then
		ret="forward"
            else
		ret="no"
            fi
	fi
    fi
    
    echo -n "$ret"
}

parse_rseqc_output $rseq_output_file
