using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class BildirimKanali : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BildirimCihazlari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: false),
                    Token = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    CihazAdi = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    KayitAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    GuncellemeAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BildirimCihazlari", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Bildirimler",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: false),
                    Baslik = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Metin = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    Rota = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    HedefKimligi = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    KaynakTuru = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    OlusmaAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Bildirimler", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BildirimCihazlari_KullaniciId",
                table: "BildirimCihazlari",
                column: "KullaniciId");

            migrationBuilder.CreateIndex(
                name: "IX_BildirimCihazlari_Token",
                table: "BildirimCihazlari",
                column: "Token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Bildirimler_OlusmaAni",
                table: "Bildirimler",
                column: "OlusmaAni");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BildirimCihazlari");

            migrationBuilder.DropTable(
                name: "Bildirimler");
        }
    }
}
