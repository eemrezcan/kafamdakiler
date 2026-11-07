namespace Kafamdakiler.Brifing;

public static class BrifingPolicies
{
    // The `izin` claim value doubles as the policy name (K-0009): reading the briefing and voting on its cards.
    // Asking for a new one is the Sahip's alone (YonetimPolicies.Sahip).
    public const string Oku = "brifing.oku";
}
