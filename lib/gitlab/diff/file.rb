module Gitlab
  module Diff
    class File
      attr_reader :diff, :diff_refs, :repository

      delegate :new_file, :deleted_file, :renamed_file,
        :old_path, :new_path, :a_mode, :b_mode,
        :submodule?, :too_large?, to: :diff, prefix: false

      def initialize(diff, diff_refs: nil, repository: nil)
        @diff = diff
        @diff_refs = diff_refs
        @repository = repository
      end

      def position(line)
        return unless diff_refs

        Position.new(
          old_path: old_path,
          new_path: new_path,
          old_line: line.old_line,
          new_line: line.new_line,
          base_id: diff_refs.base_id,
          start_id: diff_refs.start_id,
          head_id: diff_refs.head_id
        )
      end

      def line_code(line)
        return if line.meta?

        Gitlab::Diff::LineCode.generate(file_path, line.new_pos, line.old_pos)
      end

      def line_for_line_code(code)
        diff_lines.find { |line| line_code(line) == code }
      end

      def line_for_position(pos)
        diff_lines.find { |line| position(line).key == pos.key }
      end

      def position_for_line_code(code)
        line = line_for_line_code(code)
        position(line) if line
      end

      def line_code_for_position(pos)
        line = line_for_position(pos)
        line_code(line) if line
      end

      def content_commit
        repository.commit(deleted_file ? old_ref : new_ref) if diff_refs
      end

      def old_ref
        diff_refs.try(:base_id)
      end

      def new_ref
        diff_refs.try(:head_id)
      end

      # Array of Gitlab::Diff::Line objects
      def diff_lines
        @lines ||= Gitlab::Diff::Parser.new.parse(raw_diff.each_line).to_a
      end

      def highlighted_diff_lines
        @highlighted_diff_lines ||= Gitlab::Diff::Highlight.new(self, repository: self.repository).highlight
      end

      def parallel_diff_lines
        @parallel_diff_lines ||= Gitlab::Diff::ParallelDiff.new(self).parallelize
      end

      def mode_changed?
        !!(a_mode && b_mode && a_mode != b_mode)
      end

      def raw_diff
        diff.diff.to_s
      end

      def next_line(index)
        diff_lines[index + 1]
      end

      def prev_line(index)
        if index > 0
          diff_lines[index - 1]
        end
      end

      def paths
        [old_path, new_path].compact
      end

      def file_path
        new_path.presence || old_path.presence
      end

      def added_lines
        diff_lines.count(&:added?)
      end

      def removed_lines
        diff_lines.count(&:removed?)
      end

      def old_blob(commit = content_commit)
        return unless commit

        parent_id = commit.parent_id
        return unless parent_id

        repository.blob_at(parent_id, old_path)
      end

      def blob(commit = content_commit)
        return unless commit
        repository.blob_at(commit.id, file_path)
      end
    end
  end
end
