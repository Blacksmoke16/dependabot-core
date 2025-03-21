# typed: true
# frozen_string_literal: true

module Dependabot
  module Shards
    module Utils
      extend T::Sig
      extend T::Helpers

      sig { params(cmd: String).returns(String) }
      def self.run_shards_command(cmd)
        cmd = "shards #{cmd}"

        Dependabot.logger.info("Running command: `#{cmd}`")

        SharedHelpers.run_shell_command(cmd, stderr_to_stdout: false)
      end

      sig { params(dependency_files: T::Array[Dependabot::DependencyFile]).void }
      def self.write_manifest_files(dependency_files)
        dependency_files.each do |file|
          path = file.name
          dir = Pathname.new(path).dirname
          FileUtils.mkdir_p(dir)
          File.write(file.name, file.content)
        end
      end
    end
  end
end
