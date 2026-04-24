version 1.0

task quality_check_task {
    meta {
        description: "Quality control assessment based on assembly metrics"
    }

    input {
        Int genome_length          # Assembly length in base pairs
        Int number_contigs         # Total number of contigs
        Int n50_value             # N50 statistic in base pairs
        Float coverage            # Sequencing depth/coverage
        String samplename
        String docker = "python:3.11-slim"
        Int disk_size = 50
        Int memory = 1
        Int cpu = 1
    }

    command <<<
        python <<CODE
        import json
        
        # Define quality thresholds
        COVERAGE_MIN = 40
        ASSEMBLY_LENGTH_MIN = 4200000     # 4.2 Mbp in base pairs
        ASSEMBLY_LENGTH_MAX = 7000000     # 7.0 Mbp in base pairs
        NUMBER_CONTIGS_MAX = 300
        N50_VALUE_MIN = 30000
        
        # Input values
        genome_length = ~{genome_length}
        number_contigs = ~{number_contigs}
        n50_value = ~{n50_value}
        coverage = ~{coverage}
        
        # Perform quality checks
        checks = {
            "coverage_check": coverage >= COVERAGE_MIN,
            "assembly_length_check": ASSEMBLY_LENGTH_MIN <= genome_length <= ASSEMBLY_LENGTH_MAX,
            "contigs_check": number_contigs < NUMBER_CONTIGS_MAX,
            "n50_check": n50_value >= N50_VALUE_MIN
        }
        
        # Generate detailed report
        report = {
            "sample_name": "~{samplename}",
            "metrics": {
                "coverage": {
                    "value": coverage,
                    "threshold": f">= {COVERAGE_MIN}",
                    "pass": checks["coverage_check"]
                },
                "assembly_length": {
                    "value": genome_length,
                    "unit": "bp",
                    "threshold": f"{ASSEMBLY_LENGTH_MIN} - {ASSEMBLY_LENGTH_MAX} bp",
                    "pass": checks["assembly_length_check"]
                },
                "number_of_contigs": {
                    "value": number_contigs,
                    "threshold": f"< {NUMBER_CONTIGS_MAX}",
                    "pass": checks["contigs_check"]
                },
                "n50_value": {
                    "value": n50_value,
                    "unit": "bp",
                    "threshold": f">= {N50_VALUE_MIN}",
                    "pass": checks["n50_check"]
                }
            },
            "all_checks_passed": all(checks.values()),
            "checks_passed": sum(checks.values()),
            "total_checks": len(checks)
        }
        
        # Write overall pass/fail status
        overall_status = "PASS" if report["all_checks_passed"] else "FAIL"
        with open("QC_STATUS", 'w') as f:
            f.write(overall_status)
        
        # Write detailed report as JSON
        with open("~{samplename}_quality_report.json", 'w') as f:
            json.dump(report, f, indent=2)
        
        # Write TSV summary
        with open("~{samplename}_quality_summary.tsv", 'w') as f:
            f.write("Metric\tValue\tThreshold\tStatus\n")
            f.write(f"Coverage (>=)\t{coverage}\t{COVERAGE_MIN}\t{'PASS' if checks['coverage_check'] else 'FAIL'}\n")
            f.write(f"Assembly Length (Mbp)\t{genome_length/1000000:.2f}\t4.2-7.0\t{'PASS' if checks['assembly_length_check'] else 'FAIL'}\n")
            f.write(f"Number of Contigs (<)\t{number_contigs}\t300\t{'PASS' if checks['contigs_check'] else 'FAIL'}\n")
            f.write(f"N50 Value (>=)\t{n50_value}\t30000\t{'PASS' if checks['n50_check'] else 'FAIL'}\n")
            f.write(f"\nOverall Status\t{overall_status}\t-\t-\n")
        
        # Print summary to console
        print(f"\n{'='*60}")
        print(f"QUALITY CHECK REPORT: {report['sample_name']}")
        print(f"{'='*60}")
        print(f"Coverage: {coverage}x (threshold: >= {COVERAGE_MIN}x) - {'PASS' if checks['coverage_check'] else 'FAIL'}")
        print(f"Assembly Length: {genome_length/1000000:.2f} Mbp (threshold: 4.2-7.0 Mbp) - {'PASS' if checks['assembly_length_check'] else 'FAIL'}")
        print(f"Number of Contigs: {number_contigs} (threshold: < 300) - {'PASS' if checks['contigs_check'] else 'FAIL'}")
        print(f"N50 Value: {n50_value} bp (threshold: >= 30,000 bp) - {'PASS' if checks['n50_check'] else 'FAIL'}")
        print(f"\nTotal Checks Passed: {report['checks_passed']}/{report['total_checks']}")
        print(f"Overall Status: {overall_status}")
        print(f"{'='*60}\n")
        
        CODE
    >>>

    output {
        String qc_status = read_string("QC_STATUS")
        File quality_report_json = "~{samplename}_quality_report.json"
        File quality_summary_tsv = "~{samplename}_quality_summary.tsv"
    }

    runtime {
        docker: "~{docker}"
        memory: "~{memory} GB"
        cpu: "~{cpu}"
        disks: "local-disk " + disk_size + " SSD"
        disk: disk_size + " GB"
        maxRetries: 1
        preemptible: 0
    }
}
