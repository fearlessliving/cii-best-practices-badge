# frozen_string_literal: true

module StringRefinements
  refine String do
    def met?
      'Met' == self
    end

    def na?
      'N/A' == self
    end

    def unknown?
      '?' == self
    end

    def unmet?
      'Unmet' == self
    end
  end
end
