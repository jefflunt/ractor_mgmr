require 'tiny_eta'

# RactorMgmr is a job queue combined with a monitor for a list of Ractors. the
# job of a RactorMgmr is:
#
# 1. store the list of jobs to be completed
# 2. feed the worker Ractors with jobs
# 3. when a worker completes a job give it another job (if there's more work to
#   do)
# 4. generally monitor the workers to see how many jobs have been completed, as
#   well as providing status of current Ractors (:idle, :working)
#
# you create your own worker Ractors, and the RactorMgmr takes care of making
# sure those workers stay as busy as possible.
#
# Usage:
#
#   # make some workers
#   workers = 5.times.map do
#     Ractor.new do
#       loop do
#         Ractor.yield(Ractor.receive * 2)
#       end
#     end
#   end
#
#   # create some jobs
#   jobs = [1] * 1_000_000; nil
#
#   # feed the jobs to the workers via the RactorMgmr
#   rm = RactorMgmr.new(
#     jobs: jobs,
#     workers: workers
#   )
#   rm.join             # optional, if you want to wait
#
# NOTE on Ractor interface: the RactorMgmr expects to send a worker a job, and
# then be able to call #take on that Ractor. it is assumed that as soon as the
# worker returns a value from #take that that worker is available for another
# job. this means you should implement your Ractors as an infinite loop where:
# - the Ractor takes in a job definition
# - the Ractor yields some value when the job is done
#
# ... thus the worker Ractor will continue accepting jobs as long as the
# RactorMgmr keeps feeding it jobs.
#
# WARN: while the RactorMgmr is running the job list should not be altered.
#
# status:
#   - :idle if the RactorMgmr is finished
#   - :running if the RactorMgmr is running
# join: calls #join on the internal Thread, blocking until all jobs have
#   finished
class RactorMgmr
  attr_reader :status,
              :results

  def initialize(jobs:, workers:)
    @status = :idle
    @jobs = jobs
    @workers = workers
    @job_index = 0
    @jobs_finished = 0
    @results = []

    ##
    # start work
    @start_time = Time.now

    # initial job fill
    @workers.each do |w|
      w.send(@jobs[@job_index])
      @job_index += 1
    end

    # Thread for feeding workers
    @mgmr_thread = Thread.new do
      @status = :running

      loop do
        break if @job_index == @jobs.length

        w, r = Ractor.select(*@workers)
        @results << r
        @jobs_finished += 1
        w.send(@jobs[@job_index])
        @job_index += 1
      end

      @workers.map do |w|
        @results << w.take
        @jobs_finished += 1
      end

      @status = :idle
    end
  end

  def done?
    jobs_finished == @jobs.length
  end

  # the total number of jobs that will be run
  def jobs_total
    @jobs.length
  end

  # the number of jobs that have finished
  def jobs_finished
    @jobs_finished
  end

  # the number of jobs currently running
  def jobs_running
    @job_index - @jobs_finished
  end

  # the number of jobs remaining
  def jobs_remaining
    jobs_total - jobs_finished
  end

  # percentage complete as a Float in the range of 0.0..1.0
  def percent_complete_f(digits=0)
    (jobs_finished / jobs_total.to_f)
  end

  # percentage complete (a floating point number between 0.0..100.0)
  def percent_complete_s(digits=0)
    ((jobs_finished / jobs_total.to_f) * 100).round(digits)
  end

  # returns a TinyEta string for ETA time
  #
  # see: https://github.com/jefflunt/tiny_eta
  def eta
    TinyEta.eta(Time.now - @start_time, percent_complete_f)
  end

  # just like Thread#join, blocks until all jobs are complete
  def join
    @mgmr_thread.join
    nil
  end

  # out-of-the-box monitoring
  def to_s
    "RactorMgmr #{jobs_running} running, progress: #{jobs_finished}/#{jobs_total} #{percent_complete_s(1)}% (ETA #{eta})"
  end
end
