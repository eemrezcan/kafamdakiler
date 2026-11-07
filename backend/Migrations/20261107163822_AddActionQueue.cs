using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddActionQueue : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "EylemGunlukleri",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    EylemId = table.Column<Guid>(type: "uuid", nullable: true),
                    Tur = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Olay = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Aciklama = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: true),
                    Zaman = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EylemGunlukleri", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "EylemIzinleri",
                columns: table => new
                {
                    Tur = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Kip = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ArdArdaRed = table.Column<int>(type: "integer", nullable: false),
                    GuncellemeAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EylemIzinleri", x => x.Tur);
                });

            migrationBuilder.CreateTable(
                name: "Eylemler",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Tur = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Yuk = table.Column<string>(type: "jsonb", nullable: false),
                    Ozet = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Kaynak = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    DisKaynak = table.Column<bool>(type: "boolean", nullable: false),
                    Gerekce = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Guven = table.Column<double>(type: "double precision", nullable: true),
                    Durum = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    GeriAlmaBilgisi = table.Column<string>(type: "jsonb", nullable: true),
                    HataMesaji = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    KararAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    UygulamaAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    GeriAlmaAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    KararVerenId = table.Column<Guid>(type: "uuid", nullable: true),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Eylemler", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EylemGunlukleri_Zaman",
                table: "EylemGunlukleri",
                column: "Zaman");

            migrationBuilder.CreateIndex(
                name: "IX_Eylemler_Durum_CreatedAt",
                table: "Eylemler",
                columns: new[] { "Durum", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "EylemGunlukleri");

            migrationBuilder.DropTable(
                name: "EylemIzinleri");

            migrationBuilder.DropTable(
                name: "Eylemler");
        }
    }
}
