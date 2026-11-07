namespace Kafamdakiler.Takvim;

public static class TakvimServisleri
{
    // The kinds "takvim-ekle" and "takvim-tasi" are registered with the others in AddEylemler.
    public static IServiceCollection AddTakvim(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(TakvimAyari.Oku(config));
        services.AddSingleton<IGoogleTakvimIstemcisi, GoogleTakvimIstemcisi>();
        services.AddSingleton<GoogleErisimi>();
        services.AddScoped<GoogleBaglanti>();
        services.AddScoped<TakvimEsitleyici>();
        services.AddScoped<ZamanCizelgesiServisi>();
        services.AddHostedService<TakvimEsitlemeServisi>();
        return services;
    }
}
