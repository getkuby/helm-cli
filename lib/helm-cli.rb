require 'helm-rb'
require 'open3'

class HelmCLI
  class HelmError < StandardError; end

  class MissingReleaseError < HelmError; end
  class InstallError < HelmError; end
  class UpgradeError < HelmError; end

  attr_reader :kubeconfig_path, :executable

  def initialize(kubeconfig_path, executable = HelmRb.executable)
    @kubeconfig_path = kubeconfig_path
    @executable = executable
  end

  def last_status
    Thread.current[status_key]
  end

  def add_repo(name, url)
    cmd = base_cmd + ['repo', 'add', name, url]
    systemm(cmd)
  end

  def update_repos
    cmd = base_cmd + ['repo', 'update']
    systemm(cmd)
  end

  def get_release(release, namespace: 'default')
    cmd = base_cmd + ['get', 'all', release, '-n', namespace]
    backticks(cmd).tap do
      unless last_status.success?
        raise MissingReleaseError, "could not get release '#{release}': helm "\
          "exited with status code #{last_status.exitstatus}"
      end
    end
  end

  def release_exists?(release, namespace: 'default')
    get_release(release, namespace: namespace)
    last_status.exitstatus == 0
  rescue MissingReleaseError
    false
  end

  def install_chart(chart, release:, version:, namespace: 'default', params: {})
    cmd = base_cmd + ['install', release, chart]
    cmd += ['--version', version]
    cmd += ['-n', namespace]

    params.each_pair do |key, value|
      cmd += ['--set', "#{key}=#{value}"]
    end

    systemm(cmd)

    unless last_status.success?
      raise InstallError, "could not install chart '#{release}': helm "\
        "exited with status code #{last_status.exitstatus}"
    end
  end

  def upgrade_chart(chart, release:, version:, namespace: 'default', params: {})
    cmd = base_cmd + ['upgrade', release, chart]
    cmd += ['--version', version]
    cmd += ['-n', namespace]

    params.each_pair do |key, value|
      cmd += ['--set', "#{key}=#{value}"]
    end

    systemm(cmd)

    unless last_status.success?
      raise InstallError, "could not upgrade chart '#{release}': helm "\
        "exited with status code #{last_status.exitstatus}"
    end
  end

  def with_pipes(out = STDOUT, err = STDERR)
    previous_stdout = self.stdout
    previous_stderr = self.stderr
    self.stdout = out
    self.stderr = err
    yield
  ensure
    self.stdout = previous_stdout
    self.stderr = previous_stderr
  end

  def stdout
    Thread.current[stdout_key] || STDOUT
  end

  def stdout=(new_stdout)
    Thread.current[stdout_key] = new_stdout
  end

  def stderr
    Thread.current[stderr_key] || STDERR
  end

  def stderr=(new_stderr)
    Thread.current[stderr_key] = new_stderr
  end

  private

  def base_cmd
    [executable, '--kubeconfig', kubeconfig_path]
  end

  def backticks(cmd)
    cmd_s = cmd.join(' ')
    result = StringIO.new

    Open3.popen3(cmd_s) do |p_stdin, p_stdout, p_stderr, wait_thread|
      Thread.new do
        begin
          p_stdout.each { |line| result.puts(line) }
        rescue IOError
        end
      end

      Thread.new(stderr) do |t_stderr|
        begin
          p_stderr.each { |line| t_stderr.puts(line) }
        rescue IOError
        end
      end

      p_stdin.close
      self.last_status = wait_thread.value
      wait_thread.join
    end

    result.string
  end

  def systemm(cmd)
    cmd_s = cmd.join(' ')

    Open3.popen3(cmd_s) do |p_stdin, p_stdout, p_stderr, wait_thread|
      Thread.new(stdout) do |t_stdout|
        begin
          p_stdout.each { |line| t_stdout.puts(line) }
        rescue IOError
        end
      end

      Thread.new(stderr) do |t_stderr|
        begin
          p_stderr.each { |line| t_stderr.puts(line) }\
        rescue IOError
        end
      end

      p_stdin.close
      self.last_status = wait_thread.value
      wait_thread.join
    end
  end

  def last_status=(status)
    Thread.current[status_key] = status
  end

  def status_key
    :helm_cli_last_status
  end

  def stdout_key
    :helm_cli_stdout
  end

  def stderr_key
    :helm_cli_stderr
  end
end
