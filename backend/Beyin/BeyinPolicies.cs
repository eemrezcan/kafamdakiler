namespace Kafamdakiler.Beyin;

public static class BeyinPolicies
{
    // The `izin` claim value doubles as the policy name (K-0009).
    public const string Oku = "beyin.oku";

    // The day plan: add, tick, carry over, note, split a task over days (K2.3a).
    public const string PlanYaz = "plan.yaz";

    // Tasks: add and finish.
    public const string GorevYaz = "gorev.yaz";
}
