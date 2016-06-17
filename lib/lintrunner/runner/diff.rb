module Lintrunner
  module Runner
    class Diff < Base

      def run(reporter)
        warnings = []
        git_changeset.each do |patch|
          filename = patch.delta.new_file[:path]
          next if patch.delta.binary?
          next if filename.end_with?('app/styles/pattern-guide/pattern-guide.scss')
          next unless filename =~ match
          next if patch.delta.renamed?

          before_contents = contents_for(patch.delta, :src)
          after_contents = contents_for(patch.delta, :dst)

          if before_contents && after_contents
            before_file = tempfile(before_contents)
            after_file = tempfile(after_contents)

            before_messages = executor.execute(before_file, filename: filename, path: path)
            after_messages = executor.execute(after_file, filename: filename, path: path)

            line_map = line_map_for(patch)
            after_messages.each do |lint|
              same_lint = before_messages.find do |b_lint|
                b_lint.line == line_map[lint.line] &&
                  b_lint.name == lint.name && b_lint.description == lint.description
              end
              warnings << lint unless same_lint
              reporter.report(lint) unless same_lint
            end
          elsif after_contents
            after_file = tempfile(after_contents)
            after_messages = executor.execute(after_file, filename: filename, path: path)
            warnings.concat after_messages
            output = after_messages.collect do |message|
              reporter.report(message)
            end
          end
        end
        warnings
      end

      private

      def tempfile(string)
        t = Tempfile.new('diff_file')
        # ensure tempfiles aren't unlinked when GC runs by maintaining a reference to them.
        @tempfiles ||= []
        @tempfiles.push(t)
        t.print(string)
        t.flush
        t.close
        t.path
      end

      def invert(array)
        result = []
        array.each_with_index do |el, i|
          result[el] = i if el
        end
        result
      end

    end
  end
end
