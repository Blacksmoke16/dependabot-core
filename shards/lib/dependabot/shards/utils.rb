# typed: true
# frozen_string_literal: true

module Dependabot
  module Shards
    module Utils
      extend T::Sig
      extend T::Helpers

      sig do
        params(
          content: String,
          groups: T::Array[String],
          name: String,
          new_version: String
        ).returns(String)
      end
      def self.update_dep_version(content, groups, name, new_version)
        key = groups.include?("runtime") ? "dependencies" : "development_dependencies"
        # Add quotes for versions with operators (required for valid YAML)
        # Keep simple numeric versions unquoted (Crystal convention)
        new_version = if new_version.start_with?(">", "<", "=", "!")
                        "'#{new_version}'"
                      elsif new_version.start_with?("~>")
                        new_version
                      elsif new_version.match?(/^[\d.]+$/)
                        new_version
                      else
                        "'#{new_version}'"
                      end
        content.gsub(/(#{key}:\s*\n(?:\s{2,}[^\n]*\n)*\s*#{name}:\s*\n(?:\s{4,}[^\n]*\n)*\s*version:\s*).*/,
                     "\\1#{new_version}")
      end

      sig { params(cmd: String, fingerprint: T.nilable(String)).returns(String) }
      def self.run_shards_command(cmd, fingerprint: nil)
        run_command("shards #{cmd}", fingerprint: fingerprint)
      end

      sig { params(cmd: String, fingerprint: T.nilable(String)).returns(String) }
      def self.run_crystal_command(cmd, fingerprint: nil)
        run_command("crystal #{cmd}", fingerprint: fingerprint)
      end

      sig { params(cmd: String, fingerprint: T.nilable(String)).returns(String) }
      def self.run_command(cmd, fingerprint: nil)
        Dependabot.logger.info("Running command: `#{cmd}`")

        SharedHelpers.run_shell_command(cmd, fingerprint: fingerprint)
      end

      private_class_method :run_command
    end
  end
end
