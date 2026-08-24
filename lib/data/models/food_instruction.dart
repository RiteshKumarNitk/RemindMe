/// Optional instruction about food.
enum FoodInstruction {
  none,
  before,
  after,
  withFood;

  static FoodInstruction from(String value) => FoodInstruction.values
      .firstWhere((f) => f.name == value, orElse: () => FoodInstruction.none);
}
