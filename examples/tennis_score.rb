require 'diff_matcher'

set_scores = [
  [[6,4], [6,4], [6,4]],
  [[8,4], [6,9], [6,4]],
]

pat_set_scores = DiffMatcher::AllMatcher.new(
  [0..6, 0..6],
  :size => 2..3
)

invalid_scores = set_scores.map { |score| pat_set_scores.diff(score) }.compact

puts invalid_scores
