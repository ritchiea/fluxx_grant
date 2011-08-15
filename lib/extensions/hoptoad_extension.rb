# require 'delayed'
# Make sure we raise a hoptoad error if the delayed job worker fails with an error
class Delayed::Worker
  alias_method :original_handle_failed_job, :handle_failed_job

  def handle_failed_job(job, error)
    if defined?(HoptoadNotifier)
      HoptoadNotifier.notify(error) 
    end
    original_handle_failed_job(job, error)
  end
end