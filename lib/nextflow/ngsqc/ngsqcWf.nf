/*
    Example script for running the ngsQC pipeline
*/

//TODO: Add some processes
// The processes that I would want to run are:
// 1. FastQC
// 2. MultiQC
// 3. Alignment
// 4. Variant Calling -> germline calling and somatic calling
// 5. Annotation

Channel.fromFilePairs('data/*.{R1,R2}.fastq') | set { inputCh }
workflow {
    inputCh | view
}