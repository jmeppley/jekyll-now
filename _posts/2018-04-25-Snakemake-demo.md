---
layout: post
---


A friend and colleague learned how to process lots of files on grid engine and now is in need of a more portable solution. Snakemake may not be the best option in all cases, but if you already know some python, it's worth considering.

## Why snakemake

Like python, snakemake is a tool that's not necesarily the best option for any one thing, but it's good at a lot of different things. Here's what I specifically like about it:

### - It works like make
As with gnu make, you define rules with inputs and outputs (or targets and dependencies) and the program does the work of figuring out the best order to run everything.

There are a few things that it does better than make

 * running the same rules on multiple files
 * fine tuning the resource needs of individual rules
 
### - It's python
 
It uses the built in python language tokenizer with a few decalrations added to define rules, so you mix python right into your makefile. Python can be used to set up the workflow or it can be the heart of individual rules.

## The Problem

You have large number of files that you want to do the same thing to. This "thing" can be one command, or it can be a whole workflow.

### The Data
Let's grab some genomes from NCBI

#### YAML
Snakemake preferes to read in configuration from JSON and YAML files. Either works, but I like yaml.

In this case, we'll name some genome URLs from NCBI


```yaml
%%writefile genomes.yaml
genomes:
    cyanophage_p_rsm1_uid198436:
        ftp://ftp.ncbi.nih.gov/genomes/Viruses/cyanophage_p_rsm1_uid198436/NC_021071.fna 
    Prochlorococcus_sp._MIT_0701:
        ftp://ftp.ncbi.nih.gov/genomes/refseq/bacteria/Prochlorococcus_sp._MIT_0701/latest_assembly_versions/GCF_000760295.1_ASM76029v1/GCF_000760295.1_ASM76029v1_genomic.fna.gz
    Candidatus_Pelagibacter_sp._HIMB1321:
        ftp://ftp.ncbi.nih.gov/genomes/refseq/bacteria/Candidatus_Pelagibacter_sp._HIMB1321/latest_assembly_versions/GCF_900177485.1_IMG-taxon_2547132513_annotated_assembly/GCF_900177485.1_IMG-taxon_2547132513_annotated_assembly_genomic.fna.gz
    Caldimonas_manganoxidans:
        ftp://ftp.ncbi.nih.gov/genomes/refseq/bacteria/Caldimonas_manganoxidans/latest_assembly_versions/GCF_000381125.1_ASM38112v1/GCF_000381125.1_ASM38112v1_genomic.fna.gz
    Saccharomyces_arboricola:
        ftp://ftp.ncbi.nih.gov/genomes/refseq/fungi/Saccharomyces_arboricola/all_assembly_versions/suppressed/GCF_000292725.1_SacArb1.0/GCF_000292725.1_SacArb1.0_genomic.fna.gz
```


## The Makefile

#### Aside on naming
For some reason, the name "snakefile" really irks me, so I use "makefile" as the general term for workflow definitions.

#### Anyway...
The following makefile just grabs the genomes with curl, predicts genes with prodigal, and then collects all the genes into a single file.

This isn't much in the way of a workflow, but it illustrates a few key features of snakemake.

### What to look for
#### implicit looping
We provide snakemake with a set of genomes, and it handles looping over all of them.

Here we use the `expand()` function which turns a file name template and a set of values (genomes) into a list of file names.

#### parallelization
If we also tell snakemake how many threads it can use, it will schedule jobs to take full advantage of them.

#### shell and python
Snakemake glues together shell commands and lets us use python to further customize the workflow. Toward that end, we can deine python functions inline.

In this case, we have to check the URL on the fly to see if we need to decompress it.

#### resusable rules and templates
By using template placeholders ("{}") in file names, we can easily write rules that can be used on multiple files.


```python
%%writefile example1.snake
"""
This makefile downloads the listed genomes and runs prodigal on them to predict genes
"""

## Config
# the configuration gets put into the "config" object
# we pull out the genome map for simpler access (this is not strictly necessary)
genomes = config['genomes']
 
## Functions
# these functions help the rules (below) to find files
# they take a set of wildcards as input
def get_genome_url(wildcards):
    """ map from genome name to URL """ 
    return genomes[wildcards.genome]

def get_pipe(wildcards):
    """ return gunzip command if input is compressed """
    if genomes[wildcards.genome].endswith(".gz"):
        return " | gunzip -c "
    else:
        return " "

## Rules
# The first rule defines our goal
#  (in this case a collection of genes)
rule collect_all_genes:
    """ concatenate the gene calls from all genomes """
    input: expand("{genome}.faa", genome=genomes)
    output: "all_genes.faa"
    shell: "cat {input} > {output}"

# The remaining rules can be in any order
#  (here, we'll work backwards)
rule predict_genes:
    """ use prodigal to find genes """
    input: "{genome}.fna"
    output:
        "{genome}.faa",
    shell:
        "prodigal -c -i {input} -a {output} > {output}.log 2>&1"

rule download_genome:
    """ use wget here, but snakemake remote file tools are capable of checking for new versions """
    output: "{genome}.fna"
    params:
        url=get_genome_url,
        pipe=get_pipe
    shell:
        "curl -s {params.url} {params.pipe} > {output}"

```
### Dependencies
We'll use conda to make sure eveything we need is installed


```yaml
%%writefile conda.yaml
channels:
    - bioconda
    - conda-forge
dependencies:
    - snakemake
    - prodigal
```


```bash
%%bash
conda env create -p env -f conda.yaml
```


### Run

We'll give it 3 threads and watch it download 3 files at a time... 


```bash
%%bash
source activate ./env
snakemake -s example1.snake --configfile genomes.yaml -j 3 -p
```

    Building DAG of jobs...
    Using shell: /bin/bash
    Provided cores: 3
    Rules claiming more threads will be scaled down.
    Job counts:
    	count	jobs
    	1	collect_all_genes
    	5	download_genome
    	5	predict_genes
    	11
    
    rule download_genome:
        output: Caldimonas_manganoxidans.fna
        jobid: 6
        wildcards: genome=Caldimonas_manganoxidans
    
    curl -s ftp://ftp.ncbi.nih.gov/genomes/refseq/bacteria/Caldimonas_manganoxidans/latest_assembly_versions/GCF_000381125.1_ASM38112v1/GCF_000381125.1_ASM38112v1_genomic.fna.gz  | gunzip -c  > Caldimonas_manganoxidans.fna
    rule download_genome:
        output: Prochlorococcus_sp._MIT_0701.fna
        jobid: 10
        wildcards: genome=Prochlorococcus_sp._MIT_0701
    
    curl -s ftp://ftp.ncbi.nih.gov/genomes/refseq/bacteria/Prochlorococcus_sp._MIT_0701/latest_assembly_versions/GCF_000760295.1_ASM76029v1/GCF_000760295.1_ASM76029v1_genomic.fna.gz  | gunzip -c  > Prochlorococcus_sp._MIT_0701.fna
    rule download_genome:
        output: Saccharomyces_arboricola.fna
        jobid: 8
        wildcards: genome=Saccharomyces_arboricola
    
    curl -s ftp://ftp.ncbi.nih.gov/genomes/refseq/fungi/Saccharomyces_arboricola/all_assembly_versions/suppressed/GCF_000292725.1_SacArb1.0/GCF_000292725.1_SacArb1.0_genomic.fna.gz  | gunzip -c  > Saccharomyces_arboricola.fna
    Finished job 10.
    1 of 11 steps (9%) done
    
    rule download_genome:
        output: Candidatus_Pelagibacter_sp._HIMB1321.fna
        jobid: 9
        wildcards: genome=Candidatus_Pelagibacter_sp._HIMB1321
    
    curl -s ftp://ftp.ncbi.nih.gov/genomes/refseq/bacteria/Candidatus_Pelagibacter_sp._HIMB1321/latest_assembly_versions/GCF_900177485.1_IMG-taxon_2547132513_annotated_assembly/GCF_900177485.1_IMG-taxon_2547132513_annotated_assembly_genomic.fna.gz  | gunzip -c  > Candidatus_Pelagibacter_sp._HIMB1321.fna
    Finished job 6.
    2 of 11 steps (18%) done
    
    rule download_genome:
        output: cyanophage_p_rsm1_uid198436.fna
        jobid: 7
        wildcards: genome=cyanophage_p_rsm1_uid198436
    
    curl -s ftp://ftp.ncbi.nih.gov/genomes/Viruses/cyanophage_p_rsm1_uid198436/NC_021071.fna   > cyanophage_p_rsm1_uid198436.fna
    Finished job 8.
    3 of 11 steps (27%) done
    
    rule predict_genes:
        input: Saccharomyces_arboricola.fna
        output: Saccharomyces_arboricola.faa
        jobid: 3
        wildcards: genome=Saccharomyces_arboricola
    
    prodigal -c -i Saccharomyces_arboricola.fna -a Saccharomyces_arboricola.faa > Saccharomyces_arboricola.faa.log 2>&1
    Finished job 7.
    4 of 11 steps (36%) done
    
    rule predict_genes:
        input: Caldimonas_manganoxidans.fna
        output: Caldimonas_manganoxidans.faa
        jobid: 1
        wildcards: genome=Caldimonas_manganoxidans
    
    prodigal -c -i Caldimonas_manganoxidans.fna -a Caldimonas_manganoxidans.faa > Caldimonas_manganoxidans.faa.log 2>&1
    Finished job 9.
    5 of 11 steps (45%) done
    
    rule predict_genes:
        input: Prochlorococcus_sp._MIT_0701.fna
        output: Prochlorococcus_sp._MIT_0701.faa
        jobid: 5
        wildcards: genome=Prochlorococcus_sp._MIT_0701
    
    prodigal -c -i Prochlorococcus_sp._MIT_0701.fna -a Prochlorococcus_sp._MIT_0701.faa > Prochlorococcus_sp._MIT_0701.faa.log 2>&1
    Finished job 1.
    6 of 11 steps (55%) done
    
    rule predict_genes:
        input: Candidatus_Pelagibacter_sp._HIMB1321.fna
        output: Candidatus_Pelagibacter_sp._HIMB1321.faa
        jobid: 4
        wildcards: genome=Candidatus_Pelagibacter_sp._HIMB1321
    
    prodigal -c -i Candidatus_Pelagibacter_sp._HIMB1321.fna -a Candidatus_Pelagibacter_sp._HIMB1321.faa > Candidatus_Pelagibacter_sp._HIMB1321.faa.log 2>&1
    Finished job 5.
    7 of 11 steps (64%) done
    
    rule predict_genes:
        input: cyanophage_p_rsm1_uid198436.fna
        output: cyanophage_p_rsm1_uid198436.faa
        jobid: 2
        wildcards: genome=cyanophage_p_rsm1_uid198436
    
    prodigal -c -i cyanophage_p_rsm1_uid198436.fna -a cyanophage_p_rsm1_uid198436.faa > cyanophage_p_rsm1_uid198436.faa.log 2>&1
    Finished job 4.
    8 of 11 steps (73%) done
    Finished job 2.
    9 of 11 steps (82%) done
    Finished job 3.
    10 of 11 steps (91%) done
    
    rule collect_all_genes:
        input: cyanophage_p_rsm1_uid198436.faa, Prochlorococcus_sp._MIT_0701.faa, Candidatus_Pelagibacter_sp._HIMB1321.faa, Caldimonas_manganoxidans.faa, Saccharomyces_arboricola.faa
        output: all_genes.faa
        jobid: 0
    
    cat cyanophage_p_rsm1_uid198436.faa Prochlorococcus_sp._MIT_0701.faa Candidatus_Pelagibacter_sp._HIMB1321.faa Caldimonas_manganoxidans.faa Saccharomyces_arboricola.faa > all_genes.faa
    Finished job 0.
    11 of 11 steps (100%) done
    Complete log: /global/projectb/scratch/jmeppley/snakemake-demo/.snakemake/log/2018-04-25T102056.403927.snakemake.log


Notice in the output that three download rules were started before any of them finished. Then as one of the 3 sots opens up, a new rule is executed.

## Wildcard Globs
Snakemake can even build the list of files for you if they are named resonably.


There are [better instructions](http://snakemake.readthedocs.io/en/stable/project_info/faq.html#glob-wildcards) available in the [official documentation](http://snakemake.readthedocs.io/en/stable), but the basic idea is that instead of unix-like globs like:

```
ls samples/*.fna
```

We use template placeholders for wildcards, and snakemake will give us a list of all the matching strings:

```
genomes, = glob_wildcards"samples/{genome}.fna")
```

### Local example
We can run a different workflow off the downloaded genomes.


```python
!ls *.fna
```

    Caldimonas_manganoxidans.fna
    Candidatus_Pelagibacter_sp._HIMB1321.fna
    Prochlorococcus_sp._MIT_0701.fna
    Saccharomyces_arboricola.fna
    cyanophage_p_rsm1_uid198436.fna


```python
%%writefile example2.snake
"""
A toy makefile to show wildcard_globs
"""

# find *.fna and return the list of genome names
genomes, = glob_wildcards("{genome}.fna")

# tell snake make to generate a countig_count file for each genome
rule output_files:
    input: expand("{genome}.contig_count", genome=genomes)
    shell: "head {input}"

# tell snakemake how to generate a contig_count file        
rule count_contigs:
    input: "{genome}.fna"
    output: "{genome}.contig_count"
    shell: "grep -c '^>' {input} > {output}"
```


```bash
%%bash
source activate ./env
rm -f *.contig_count
snakemake -s example2.snake
```

    ==> Caldimonas_manganoxidans.contig_count <==
    89
    
    ==> cyanophage_p_rsm1_uid198436.contig_count <==
    1
    
    ==> Prochlorococcus_sp._MIT_0701.contig_count <==
    53
    
    ==> Candidatus_Pelagibacter_sp._HIMB1321.contig_count <==
    1
    
    ==> Saccharomyces_arboricola.contig_count <==
    35


    Building DAG of jobs...
    Using shell: /bin/bash
    Provided cores: 1
    Rules claiming more threads will be scaled down.
    Job counts:
    	count	jobs
    	5	count_contigs
    	1	output_files
    	6
    
    rule count_contigs:
        input: Saccharomyces_arboricola.fna
        output: Saccharomyces_arboricola.contig_count
        jobid: 4
        wildcards: genome=Saccharomyces_arboricola
    
    Finished job 4.
    1 of 6 steps (17%) done
    
    rule count_contigs:
        input: Caldimonas_manganoxidans.fna
        output: Caldimonas_manganoxidans.contig_count
        jobid: 1
        wildcards: genome=Caldimonas_manganoxidans
    
    Finished job 1.
    2 of 6 steps (33%) done
    
    rule count_contigs:
        input: Prochlorococcus_sp._MIT_0701.fna
        output: Prochlorococcus_sp._MIT_0701.contig_count
        jobid: 2
        wildcards: genome=Prochlorococcus_sp._MIT_0701
    
    Finished job 2.
    3 of 6 steps (50%) done
    
    rule count_contigs:
        input: Candidatus_Pelagibacter_sp._HIMB1321.fna
        output: Candidatus_Pelagibacter_sp._HIMB1321.contig_count
        jobid: 5
        wildcards: genome=Candidatus_Pelagibacter_sp._HIMB1321
    
    Finished job 5.
    4 of 6 steps (67%) done
    
    rule count_contigs:
        input: cyanophage_p_rsm1_uid198436.fna
        output: cyanophage_p_rsm1_uid198436.contig_count
        jobid: 3
        wildcards: genome=cyanophage_p_rsm1_uid198436
    
    Finished job 3.
    5 of 6 steps (83%) done
    
    rule output_files:
        input: Caldimonas_manganoxidans.contig_count, cyanophage_p_rsm1_uid198436.contig_count, Prochlorococcus_sp._MIT_0701.contig_count, Candidatus_Pelagibacter_sp._HIMB1321.contig_count, Saccharomyces_arboricola.contig_count
        jobid: 0
    
    Finished job 0.
    6 of 6 steps (100%) done
    Complete log: /global/projectb/scratch/jmeppley/snakemake-demo/.snakemake/log/2018-04-25T102130.106210.snakemake.log

