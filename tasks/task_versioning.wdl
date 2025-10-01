version 1.0

task version_capture {
  input {
    String? timezone
    String docker = "neranjan007/jq:1.6.2"
    Int cpu = 1
    Int memory = 2
  }
  meta {
    volatile: true
  }
  command {
    WF_Version="AIR v1.0.0"
    ~{default='' 'export TZ=' + timezone}
    date +"%Y-%m-%d" > TODAY
    echo "$WF_Version" > WF_VERSION
  }
  output {
    String date = read_string("TODAY")
    String wf_version = read_string("WF_VERSION")
  }
  runtime {
        docker: "~{docker}"
        memory: "~{memory} GB"
        cpu: cpu
        disks: "local-disk 50 SSD"
        preemptible: 0 
  }
}