using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddTakvim : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GoogleBaglantilari",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false),
                    YenilemeTokeni = table.Column<string>(type: "text", nullable: false),
                    Durum = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Kapsamlar = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    BaglananAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    BaglayanId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GoogleBaglantilari", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "GoogleYetkilendirmeleri",
                columns: table => new
                {
                    StateOzeti = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    KodDogrulayici = table.Column<string>(type: "text", nullable: false),
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: false),
                    BitisAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GoogleYetkilendirmeleri", x => x.StateOzeti);
                });

            migrationBuilder.CreateTable(
                name: "TakvimEsitlemeleri",
                columns: table => new
                {
                    TakvimKimligi = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    SyncToken = table.Column<string>(type: "text", nullable: true),
                    SonTamEsitleme = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    SonEsitleme = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TakvimEsitlemeleri", x => x.TakvimKimligi);
                });

            migrationBuilder.CreateTable(
                name: "TakvimEtkinlikleri",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TakvimKimligi = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    GoogleKimligi = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    Baslik = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Baslangic = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Bitis = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    TumGun = table.Column<bool>(type: "boolean", nullable: false),
                    BaslangicGunu = table.Column<DateOnly>(type: "date", nullable: false),
                    BitisGunu = table.Column<DateOnly>(type: "date", nullable: false),
                    Yer = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Etag = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    GuncellemeAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TakvimEtkinlikleri", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GoogleYetkilendirmeleri_BitisAni",
                table: "GoogleYetkilendirmeleri",
                column: "BitisAni");

            migrationBuilder.CreateIndex(
                name: "IX_TakvimEtkinlikleri_Baslangic",
                table: "TakvimEtkinlikleri",
                column: "Baslangic");

            migrationBuilder.CreateIndex(
                name: "IX_TakvimEtkinlikleri_TakvimKimligi_GoogleKimligi",
                table: "TakvimEtkinlikleri",
                columns: new[] { "TakvimKimligi", "GoogleKimligi" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GoogleBaglantilari");

            migrationBuilder.DropTable(
                name: "GoogleYetkilendirmeleri");

            migrationBuilder.DropTable(
                name: "TakvimEsitlemeleri");

            migrationBuilder.DropTable(
                name: "TakvimEtkinlikleri");
        }
    }
}
