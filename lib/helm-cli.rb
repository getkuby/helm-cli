require 'helm-rb'

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
      raise InstallError, "could not upgrade chart '#{name}': helm "\
        "exited with status code #{last_status.exitstatus}"
    end
  end

  private

  def base_cmd
    [executable, '--kubeconfig', kubeconfig_path]
  end

  def backticks(cmd)
    cmd_s = cmd.join(' ')
    `#{cmd_s}`.tap do
      self.last_status = $?
    end
  end

  def systemm(cmd)
    cmd_s = cmd.join(' ')
    system(cmd_s).tap do
      self.last_status = $?
    end
  end

  def last_status=(status)
    Thread.current[status_key] = status
  end

  def status_key
    :helm_rb_cli_last_status
  end
end
