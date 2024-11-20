#!/usr/bin/env bash

# unzip the files
gunzip -c EC-SDA_S28_R1_001.fastq.gz
gunzip -c EC-SDA_S28_R2_001.fastq.gz

# make directories for quality control,
mkdir qc_reports 

# quality control using Fastqc
fastqc EC-SDA_S28_R1_001.fastq EC-SDA_S28_R2_001.fastq -o qc_reports

# summarise qc results with multiqc
multiqc qc_reports

# trimming with Sickle
sickle pe -f EC-SDA_S28_R1_001.fastq -r EC-SDA_S28_R2_001.fastq \
-t sanger -o trimmed.EC-SDA_S28_R1_001.fastq -p trimmed.EC-SDA_S28_R2_001.fastq  \
-s singletons.EC-SDA_S28_001.fastq.gz -q 20 -l 50

# genome size estimation using jellyfish
jellyfish count -t 30 -C -m 21 -s 10G \
  -o 21mer_out.jf trimmed.EC-SDA_S28_R1_001.fastq trimmed.EC-SDA_S28_R2_001.fastq

# generate histogram using jellyfish
jellyfish histo -o 21mer.histo 21mer_out.jf

# short read assembly with MaSuRCA
masurca config.txt

# run the assemble.sh script
./assemble.sh

# evaluating genome assembly with bwa
bwa index CA/primary.genome.scf.fasta
bwa mem CA/primary.genome.scf.fasta trimmed.EC-SDA_S28_R1_001.fastq trimmed.EC-SDA_S28_R2_001.fastq > alignment.sam
samtools view -bS alignment.sam | samtools sort -o alignment.sorted.bam
samtools index alignment.sorted.bam
samtools flagstat alignment.sorted.bam

# evaluating genome assembly with quast 
quast.py CA/primary.genome.scf.fasta -o quast_results

# genome annotation with Prokka
docker pull staphb/prokka
docker run -it -v $(pwd):/data staphb/prokka --outdir ProkkaResults --genus Streptomyces --species albidoflavus --cpus 6 primary.genome.scf.fasta
