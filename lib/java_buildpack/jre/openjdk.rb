# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/jre'
require 'java_buildpack/jre/details'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'

module JavaBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [JavaBuildpack::Util::Properties] :system_properties the properties provided by the user
    def initialize(context = {})
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @system_properties = context[:system_properties]
      @details = Details.new(@system_properties)
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will always return _some_ value,
    # so it should only be used once that application has already been established to be a Java application.
    #
    # @return [String, nil] returns +jre-<vendor>-<version>+.
    def detect
      id @details
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      application_cache = JavaBuildpack::Util::ApplicationCache.new

      download_start_time = Time.now
      print "-----> Downloading #{@details.vendor} #{@details.version} JRE from #{@details.uri} "

      application_cache.get(id(@details), @details.uri) do |file|
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
      @java_opts << resolve_heap_size
      @java_opts << resolve_permgen_size
      @java_opts << resolve_stack_size
    end

    private

    HEAP_SIZE = 'java.heap.size'.freeze

    JAVA_HOME = '.java'.freeze

    PERMGEN_SIZE = 'java.permgen.size'.freeze

    STACK_SIZE = 'java.stack.size'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "-----> Expanding JRE to #{JAVA_HOME} "

      java_home = File.join @app_dir, JAVA_HOME
      system "rm -rf #{java_home}"
      system "mkdir -p #{java_home}"
      system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def id(details)
      "jre-#{details.vendor}-#{details.version}"
    end

    def resolve(key, whitespace_message_pattern, value_pattern)
      value = @system_properties[key]
      raise whitespace_message_pattern % value if value =~ /\s/
      value.nil? ? nil : value_pattern % value
    end

    def resolve_heap_size
      resolve HEAP_SIZE,  'Invalid heap size \'%s\': embedded whitespace', '-Xmx%s'
    end

    def resolve_permgen_size
      resolve PERMGEN_SIZE, 'Invalid PermGen size \'%s\': embedded whitespace', '-XX:MaxPermSize=%s'
    end

    def resolve_stack_size
      resolve STACK_SIZE, 'Invalid stack size \'%s\': embedded whitespace', '-Xss%s'
    end

  end

end
