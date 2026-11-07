namespace Kafamdakiler.Eylemler;

// Thrown by a kind's GeriAlAsync when taking the effect back would overwrite something that changed since (a calendar event edited
// on Google after the action made it). Nothing was undone. The queue answers 409 with this message and leaves the action as applied,
// instead of the generic "could not be undone".
public class GeriAlmaCatismasiException(string mesaj) : Exception(mesaj);
