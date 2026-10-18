/*
 * drmaa_latency - measure how long drmaa_wait() takes to report a finished job.
 *
 * The interesting number is not the total round trip, which includes the time
 * the job itself spends running, but the gap between the moment the job stops
 * and the moment drmaa_wait() returns. The job therefore stamps its own end
 * time into a file; the client subtracts that from its own clock. Both run in
 * the same container, so the two timestamps share a clock.
 *
 * Output is one TSV line per iteration on stdout, prefixed with RESULT, plus
 * diagnostics on stderr. Columns:
 *
 *   RESULT <iter> <job_id> <submit_to_wait> <job_end_to_wait> <exit_status>
 *
 * submit_to_wait   seconds from drmaa_run_job() returning to drmaa_wait()
 *                  returning; this is what a caller of a synchronous wrapper
 *                  observes.
 * job_end_to_wait  seconds from the job writing its end stamp to drmaa_wait()
 *                  returning; this is the event delivery latency proper.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "drmaa.h"

static double now_seconds(void)
{
   struct timespec ts;

   clock_gettime(CLOCK_REALTIME, &ts);
   return (double) ts.tv_sec + (double) ts.tv_nsec / 1e9;
}

/*
 * The job writes its end time as "<seconds>.<nanoseconds>" via date(1). Poll
 * for it briefly: the file is created by the job on the execution side and may
 * lag a moment behind the job actually exiting. Returns 0 when no stamp shows
 * up, which the caller reports as a missing measurement rather than a fake one.
 */
static double read_job_end_stamp(const char *path)
{
   int attempt;

   for (attempt = 0; attempt < 50; attempt++) {
      FILE *fp = fopen(path, "r");

      if (fp != NULL) {
         double stamp = 0.0;
         int scanned = fscanf(fp, "%lf", &stamp);

         fclose(fp);
         if (scanned == 1 && stamp > 0.0) {
            return stamp;
         }
      }
      usleep(20000);
   }

   return 0.0;
}

int main(int argc, char *argv[])
{
   char diagnosis[DRMAA_ERROR_STRING_BUFFER];
   char job_id[DRMAA_JOBNAME_BUFFER];
   const char *job_script;
   const char *stamp_dir;
   int iterations;
   int iter;
   int ret;

   if (argc != 4) {
      fprintf(stderr, "usage: %s <iterations> <job_script> <stamp_dir>\n", argv[0]);
      return 2;
   }

   iterations = atoi(argv[1]);
   job_script = argv[2];
   stamp_dir = argv[3];

   /*
    * drmaa_init() is where the SGE_JAPI_EDTIME validation runs, so a rejected
    * value shows up here and not at wait time. Report it verbatim: the exact
    * wording is what the bug report quotes.
    */
   diagnosis[0] = '\0';
   ret = drmaa_init(NULL, diagnosis, sizeof(diagnosis) - 1);
   if (ret != DRMAA_ERRNO_SUCCESS) {
      fprintf(stderr, "INITFAIL\t%d\t%s\n", ret, diagnosis);
      printf("INITFAIL\t%d\t%s\n", ret, diagnosis);
      return 1;
   }
   fprintf(stderr, "drmaa_init() ok\n");

   for (iter = 0; iter < iterations; iter++) {
      drmaa_job_template_t *jt = NULL;
      const char *args[2];
      char stamp_path[1024];
      char wait_job_id[DRMAA_JOBNAME_BUFFER];
      double submitted;
      double waited;
      double job_end;
      int stat = 0;
      int exited = 0;
      int exit_status = -1;

      snprintf(stamp_path, sizeof(stamp_path), "%s/stamp.%d.%d", stamp_dir,
               (int) getpid(), iter);
      unlink(stamp_path);

      ret = drmaa_allocate_job_template(&jt, diagnosis, sizeof(diagnosis) - 1);
      if (ret != DRMAA_ERRNO_SUCCESS) {
         fprintf(stderr, "drmaa_allocate_job_template: %s\n", diagnosis);
         break;
      }

      drmaa_set_attribute(jt, DRMAA_REMOTE_COMMAND, job_script, diagnosis,
                          sizeof(diagnosis) - 1);
      args[0] = stamp_path;
      args[1] = NULL;
      drmaa_set_vector_attribute(jt, DRMAA_V_ARGV, args, diagnosis,
                                 sizeof(diagnosis) - 1);
      /* Keep the spool clean; output would only pile up over many iterations. */
      drmaa_set_attribute(jt, DRMAA_OUTPUT_PATH, ":/dev/null", diagnosis,
                          sizeof(diagnosis) - 1);
      drmaa_set_attribute(jt, DRMAA_ERROR_PATH, ":/dev/null", diagnosis,
                          sizeof(diagnosis) - 1);
      drmaa_set_attribute(jt, DRMAA_JOIN_FILES, "y", diagnosis,
                          sizeof(diagnosis) - 1);

      ret = drmaa_run_job(job_id, sizeof(job_id) - 1, jt, diagnosis,
                          sizeof(diagnosis) - 1);
      submitted = now_seconds();
      drmaa_delete_job_template(jt, diagnosis, sizeof(diagnosis) - 1);

      if (ret != DRMAA_ERRNO_SUCCESS) {
         fprintf(stderr, "drmaa_run_job: %s\n", diagnosis);
         break;
      }

      ret = drmaa_wait(job_id, wait_job_id, sizeof(wait_job_id) - 1, &stat,
                       DRMAA_TIMEOUT_WAIT_FOREVER, NULL, diagnosis,
                       sizeof(diagnosis) - 1);
      waited = now_seconds();

      if (ret != DRMAA_ERRNO_SUCCESS) {
         fprintf(stderr, "drmaa_wait: %s\n", diagnosis);
         break;
      }

      drmaa_wifexited(&exited, stat, diagnosis, sizeof(diagnosis) - 1);
      if (exited) {
         drmaa_wexitstatus(&exit_status, stat, diagnosis, sizeof(diagnosis) - 1);
      }

      job_end = read_job_end_stamp(stamp_path);
      unlink(stamp_path);

      printf("RESULT\t%d\t%s\t%.3f\t%.3f\t%d\n", iter, job_id,
             waited - submitted,
             job_end > 0.0 ? waited - job_end : -1.0,
             exit_status);
      fflush(stdout);
   }

   ret = drmaa_exit(diagnosis, sizeof(diagnosis) - 1);
   if (ret != DRMAA_ERRNO_SUCCESS) {
      fprintf(stderr, "drmaa_exit: %s\n", diagnosis);
   }

   return 0;
}
