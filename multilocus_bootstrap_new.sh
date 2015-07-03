#!/bin/bash

set -u
set -e
set -o pipefail

if [ $# -lt 7 ]; then  
  echo "USAGE: 
$0 [number of bootstraps] [dir] [FILENAME] [outdir] [outname] [sampling] [weightfile] [random seed]

   dir: should be a directory that includes only one directory per gene

   FILENAME: dir/*/FILENAME should give the name of gene tree input files (one file per gene) (bootstrap trees for site-only and gene/site, bestml trees for gene-only sampling strategy)

   outdir: is where the results will be placed

   outname: is the prefix of the output files

   sampling: can be either site, genesite or gene (for site-only, gene/site or gene-only resampling). 

   weightfile: if - is given, it's ignored; otherwise, each gene is multiplied by the number of lines in weightfile under dir/*
   
   seed: a random seed number (leave blank and it will use \$RANDOM)"
   exit 1
fi

H=`dirname $0`
d=$2
outdir=$4
outname="$5"
sampling=$6
weightfile=$7
seed=$RANDOM
test $# -gt 7 && seed=$8
RANDOM=$seed

echo seed is $seed 

mkdir -p $outdir

if [[ "$sampling" == "gene" ]]
then
trees=($d/*)
n_trees=${#trees[@]}
for x in $(seq 1 1 $1);
do
	awk_seed=$RANDOM	
	id_trees=($(awk -v seed=$awk_seed -v n=$n_trees --source 'BEGIN{srand(seed);for (i=0;i<n;++i){print int(rand() * n)}}')) #From 0 to n-1

	for ((i=0;i<$n_trees;++i))
	do
		if [[ ! -f ${trees[${id_trees[$i]}]}/$3 ]]
		then
			echo "${trees[${id_trees[$i]}]}/$3 file is not available, please, check your input folder and input name"
		else
        		cat ${trees[${id_trees[$i]}]}/$3 >> $outdir/$outname.$x;
		fi
	done
done

echo "Done!"
else
for x in $(seq 1 1 $1); do >$outdir/$outname.$x; done

assign=`python $H/mlbs-gene-sampling.py $1 $seed $3 $sampling $d/*`
test $? == 0 || exit 1
echo "${assign}"
while read b c; do
   n=0
   yd=$d/$b
   y=$yd/$3
   if [ -f $y ]; then
      IFS=',' read -ra REPS <<< "$c"
      le=${#REPS[@]}
      if [ $weightfile == "-" ]; then
         w=1
      else
         w=`cat $yd/$weightfile|wc -l`
      fi
      echo $b, $le, $w   
      while read line; do
        ind=${REPS[$n]}
        t=`echo $line| sed -e "s/)[0-9.e-]*/)/g"`
        test "$t" == "" && exit 1; #echo ERROR: tree is empty
        for x in $(seq 1 1 $w); do echo $t >> $outdir/$outname.$ind; done
        n=$((n + 1))
        if [ $n == $le ]; then break; fi
      done < $y      
      test $n == $le || exit 1;
   fi
done < <(echo "${assign}")

#echo "`wc -l $outdir/$outname.$x|tail -n1`" "$(($1 * f)) total"
#test "`wc -l $outdir/$outname.$x|tail -n1`" == "$(($1 * f)) total" || exit 1

echo "Done!"
fi
