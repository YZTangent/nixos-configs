{ ... }:

{
  services.cron = {
    enable = true;
    systemCronJobs = [
      "* * * * *      yztangent $HOME/Scripts/canvas/canvas-download-job.sh >> $HOME/Scripts/canvas/download_job.log"
    ];
  };

  services.openssh.enable = true;
}
