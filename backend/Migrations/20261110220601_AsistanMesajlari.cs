using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AsistanMesajlari : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AsistanMesajlari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: false),
                    Zaman = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Tur = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Metin = table.Column<string>(type: "character varying(5000)", maxLength: 5000, nullable: true),
                    FotografId = table.Column<Guid>(type: "uuid", nullable: true),
                    Kaynak = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    GirdiId = table.Column<Guid>(type: "uuid", nullable: false),
                    SonuclarJson = table.Column<string>(type: "jsonb", nullable: true),
                    SoruJson = table.Column<string>(type: "jsonb", nullable: true),
                    CevaplandiAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AsistanMesajlari", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AsistanMesajlari_GirdiTalebi",
                table: "AsistanMesajlari",
                columns: new[] { "KullaniciId", "GirdiId" },
                unique: true,
                filter: "\"Tur\" = 'Kullanici' AND \"Kaynak\" <> 'cevap'");

            migrationBuilder.CreateIndex(
                name: "IX_AsistanMesajlari_KullaniciId_Zaman",
                table: "AsistanMesajlari",
                columns: new[] { "KullaniciId", "Zaman" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AsistanMesajlari");
        }
    }
}
